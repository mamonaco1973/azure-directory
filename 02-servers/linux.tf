# ==============================================================================
# Linux VM: Ubuntu Admin Instance (Credentialed + Cloud-Init)
# ------------------------------------------------------------------------------
# Purpose:
#   - Provisions a small Ubuntu VM used as a Linux-side admin / utility host.
#   - Generates a strong local "ubuntu" password and stores it in Key Vault.
#   - Creates networking (Public IP + NIC) and attaches the NIC to the VM.
#   - Bootstraps the VM with cloud-init (custom_data) using a rendered template.
#   - Assigns a system-managed identity and grants it Key Vault read access.
#
# Notes:
#   - This module assumes the Resource Group, Subnet, and Key Vault already
#     exist and are referenced via data sources.
#   - Password authentication is explicitly enabled for the ubuntu account.
#   - The VM depends on a Windows VM extension completing first (join_script),
#     typically to ensure domain services / prerequisites are ready.
# ==============================================================================

# ------------------------------------------------------------------------------
# Random Password: Local ubuntu account
# ------------------------------------------------------------------------------
# Generates a strong password with a constrained special-character set to keep
# it compatible with scripts, JSON encoding, and downstream consumers.
# ------------------------------------------------------------------------------
resource "random_password" "ubuntu_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# ------------------------------------------------------------------------------
# Key Vault Secret: Store ubuntu credentials as JSON
# ------------------------------------------------------------------------------
# Stores the username and generated password in the existing Key Vault.
# ------------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "ubuntu_secret" {
  name = "ubuntu-credentials"
  value = jsonencode({
    username = "ubuntu"
    password = random_password.ubuntu_password.result
  })
  key_vault_id = data.azurerm_key_vault.ad_key_vault.id
  content_type = "application/json"
}

# ------------------------------------------------------------------------------
# Public IP: Internet-accessible endpoint for the Linux VM
# ------------------------------------------------------------------------------
# Uses Standard SKU and Static allocation, and assigns a unique DNS label using
# a random suffix to avoid collisions.
# ------------------------------------------------------------------------------
resource "azurerm_public_ip" "linux_vm_ip" {
  name                = "linux-vm-ip"
  location            = data.azurerm_resource_group.ad.location
  resource_group_name = data.azurerm_resource_group.ad.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "linux-vm-${random_string.vm_suffix.result}"
}

# ------------------------------------------------------------------------------
# Network Interface: NIC for the Linux VM
# ------------------------------------------------------------------------------
# Attaches the NIC to the existing VM subnet and binds the Public IP.
# ------------------------------------------------------------------------------
resource "azurerm_network_interface" "linux_vm_nic" {
  name                = "linux-vm-nic"
  location            = data.azurerm_resource_group.ad.location
  resource_group_name = data.azurerm_resource_group.ad.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.linux_vm_ip.id
  }
}

# ------------------------------------------------------------------------------
# Linux VM: Ubuntu 24.04 LTS instance
# ------------------------------------------------------------------------------
# Provisions a small VM, attaches NIC, configures OS disk, and passes cloud-init
# via custom_data for first-boot configuration.
# ------------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "linux_ad_instance" {
  name                            = "linux-ad-${random_string.vm_suffix.result}"
  location                        = data.azurerm_resource_group.ad.location
  resource_group_name             = data.azurerm_resource_group.ad.name
  size                            = "Standard_B1s"
  admin_username                  = "ubuntu"
  admin_password                  = random_password.ubuntu_password.result
  disable_password_authentication = false

  # ---------------------------------------------------------------------------
  # Networking: Attach the previously created NIC
  # ---------------------------------------------------------------------------
  network_interface_ids = [
    azurerm_network_interface.linux_vm_nic.id
  ]

  # ---------------------------------------------------------------------------
  # OS Disk: Basic locally redundant storage for lab/dev use
  # ---------------------------------------------------------------------------
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # ---------------------------------------------------------------------------
  # Base Image: Canonical Ubuntu 24.04 LTS (latest)
  # ---------------------------------------------------------------------------
  source_image_reference {
    publisher = "canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  # ---------------------------------------------------------------------------
  # Cloud-Init: Pass templated bootstrap script as custom_data
  # ---------------------------------------------------------------------------
  # The script is rendered locally using templatefile() and then base64-encoded
  # as required by the Azure API for custom_data.
  # ---------------------------------------------------------------------------
  custom_data = base64encode(templatefile("./scripts/custom_data.sh", {
    vault_name  = data.azurerm_key_vault.ad_key_vault.name
    domain_fqdn = "mcloud.mikecloud.com"
  }))

  # ---------------------------------------------------------------------------
  # Managed Identity: Enable system-assigned identity for Key Vault access
  # ---------------------------------------------------------------------------
  identity {
    type = "SystemAssigned"
  }

  # ---------------------------------------------------------------------------
  # Dependency: Ensure Windows-side bootstrap completes before this VM
  # ---------------------------------------------------------------------------
  depends_on = [azurerm_virtual_machine_extension.join_script]
}

# ------------------------------------------------------------------------------
# RBAC: Grant Linux VM identity permission to read Key Vault secrets
# ------------------------------------------------------------------------------
# Allows the VM to retrieve credentials and configuration secrets at runtime.
# ------------------------------------------------------------------------------
resource "azurerm_role_assignment" "vm_lnx_key_vault_secrets_user" {
  scope                = data.azurerm_key_vault.ad_key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.linux_ad_instance.identity[0].principal_id
}