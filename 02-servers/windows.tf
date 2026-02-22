# ==============================================================================
# Windows VM: AD Administration Instance (Credentialed + Domain Join Extension)
# ------------------------------------------------------------------------------
# Purpose:
#   - Provisions a Windows Server VM used for AD / AADDS administration.
#   - Generates a strong local admin password and stores it in Key Vault.
#   - Creates networking (Public IP + NIC) and attaches the NIC to the VM.
#   - Assigns a system-managed identity and grants it Key Vault read access.
#   - Runs a Custom Script Extension to download and execute an AD join script
#     staged in Azure Storage (via SAS token).
#
# Notes:
#   - This module assumes the Resource Group, Subnet, and Key Vault already
#     exist and are referenced via data sources.
#   - The VM depends on the managed domain admin user/secret being created
#     first (admin_secret + mcloud_admin) to support domain join automation.
#   - Public RDP exposure is controlled by the VM subnet NSG (defined elsewhere).
# ==============================================================================

# ------------------------------------------------------------------------------
# Random Password: Local Windows admin user (adminuser)
# ------------------------------------------------------------------------------
# Generates a strong password with a constrained special-character set to reduce
# issues with JSON, scripts, or Windows tooling escaping.
# ------------------------------------------------------------------------------
resource "random_password" "win_adminuser_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# ------------------------------------------------------------------------------
# Random Suffix: Unique naming for VM and DNS label
# ------------------------------------------------------------------------------
resource "random_string" "vm_suffix" {
  length  = 6
  special = false
  upper   = false
}

# ------------------------------------------------------------------------------
# Key Vault Secret: Store local admin credentials as JSON
# ------------------------------------------------------------------------------
# Stores a local Windows username (.\adminuser) plus the generated password.
# ------------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "win_adminuser_secret" {
  name = "win-adminuser-credentials"
  value = jsonencode({
    username = ".\\adminuser"
    password = random_password.win_adminuser_password.result
  })
  key_vault_id = data.azurerm_key_vault.ad_key_vault.id
  content_type = "application/json"
}

# ------------------------------------------------------------------------------
# Public IP: Internet-accessible endpoint for the Windows VM
# ------------------------------------------------------------------------------
# Standard SKU + Static allocation with a unique DNS label.
# ------------------------------------------------------------------------------
resource "azurerm_public_ip" "windows_vm_ip" {
  name                = "windows-vm-ip"
  location            = data.azurerm_resource_group.ad.location
  resource_group_name = data.azurerm_resource_group.ad.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "window-vm-${random_string.vm_suffix.result}"
}

# ------------------------------------------------------------------------------
# Network Interface: NIC for Windows VM
# ------------------------------------------------------------------------------
# Attaches the NIC to the existing VM subnet and binds the Public IP.
# ------------------------------------------------------------------------------
resource "azurerm_network_interface" "windows_vm_nic" {
  name                = "windows-vm-nic"
  location            = data.azurerm_resource_group.ad.location
  resource_group_name = data.azurerm_resource_group.ad.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.windows_vm_ip.id
  }
}

# ------------------------------------------------------------------------------
# Windows VM: Windows Server 2022 (Datacenter)
# ------------------------------------------------------------------------------
# Provisions the VM, attaches NIC, configures disk, assigns identity, and sets
# explicit dependencies needed for domain-join prerequisites.
# ------------------------------------------------------------------------------
resource "azurerm_windows_virtual_machine" "windows_ad_instance" {
  name                = "win-ad-${random_string.vm_suffix.result}"
  location            = data.azurerm_resource_group.ad.location
  resource_group_name = data.azurerm_resource_group.ad.name
  size                = "Standard_DS1_v2"
  admin_username      = "adminuser"
  admin_password      = random_password.win_adminuser_password.result

  # ---------------------------------------------------------------------------
  # Networking: Attach the previously created NIC
  # ---------------------------------------------------------------------------
  network_interface_ids = [
    azurerm_network_interface.windows_vm_nic.id
  ]

  # ---------------------------------------------------------------------------
  # OS Disk: Basic locally redundant storage for lab/dev use
  # ---------------------------------------------------------------------------
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # ---------------------------------------------------------------------------
  # Base Image: Windows Server 2022 Datacenter (latest)
  # ---------------------------------------------------------------------------
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  # ---------------------------------------------------------------------------
  # Managed Identity: Enable system-assigned identity for Key Vault access
  # ---------------------------------------------------------------------------
  identity {
    type = "SystemAssigned"
  }

  # ---------------------------------------------------------------------------
  # Dependency: Ensure admin identity/secret prerequisites exist
  # ---------------------------------------------------------------------------
  depends_on = [
    azurerm_key_vault_secret.admin_secret,
    azuread_user.mcloud_admin
  ]
}

# ------------------------------------------------------------------------------
# RBAC: Grant Windows VM identity permission to read Key Vault secrets
# ------------------------------------------------------------------------------
# Allows the VM to retrieve secrets required for domain join and administration.
# ------------------------------------------------------------------------------
resource "azurerm_role_assignment" "vm_win_key_vault_secrets_user" {
  scope                = data.azurerm_key_vault.ad_key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_windows_virtual_machine.windows_ad_instance.identity[0].principal_id
}

# ------------------------------------------------------------------------------
# VM Extension: Custom Script Extension (AD Join / Bootstrap)
# ------------------------------------------------------------------------------
# Downloads the PowerShell script from Azure Storage (using SAS) and executes it.
# Output is appended to a log file on the VM for troubleshooting.
# ------------------------------------------------------------------------------
resource "azurerm_virtual_machine_extension" "join_script" {
  name                 = "customScript"
  virtual_machine_id   = azurerm_windows_virtual_machine.windows_ad_instance.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  timeouts {
    create = "90m"
    update = "90m"
    delete = "90m"
  }

  settings = <<SETTINGS
  {
    "fileUris": ["https://${azurerm_storage_account.scripts_storage.name}.blob.core.windows.net/${azurerm_storage_container.scripts.name}/${azurerm_storage_blob.ad_join_script.name}?${data.azurerm_storage_account_sas.script_sas.sas}"],
    "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -File ad-join.ps1 *>> C:\\\\WindowsAzure\\\\Logs\\\\ad-join.log"
  }
  SETTINGS
}

# ------------------------------------------------------------------------------
# Optional Output: AD join script URL (with SAS)
# ------------------------------------------------------------------------------
# Useful for debugging script access outside the VM extension workflow.
# ------------------------------------------------------------------------------
# output "ad_join_script_url" {
#   value       = "https://${azurerm_storage_account.scripts_storage.name}.blob.core.windows.net/${azurerm_storage_container.scripts.name}/${azurerm_storage_blob.ad_join_script.name}?${data.azurerm_storage_account_sas.script_sas.sas}"
#   description = "URL to the AD join script with SAS token."
# }