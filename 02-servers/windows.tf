# --- User: adminuser ---

# Generate a random password for "adminuser"
resource "random_password" "win_adminuser_password" {
  length             = 24
  special            = true
  override_special   = "!@#$%"
}

resource "random_string" "vm_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Create secret for local windows adminuser 

resource "azurerm_key_vault_secret" "win_adminuser_secret" {
  name         = "win-adminuser-credentials"
  value        = jsonencode({
    username = ".\\adminuser"
    password = random_password.win_adminuser_password.result
  })
  key_vault_id = data.azurerm_key_vault.ad_key_vault.id
  content_type = "application/json"
}


# Define a network interface to connect the VM to the network

resource "azurerm_network_interface" "windows_vm_nic" {
  name                = "windows-vm-nic"                            # Name of the NIC
  location            = data.azurerm_resource_group.ad.location   # VM location matches the resource group
  resource_group_name = data.azurerm_resource_group.ad.name       # Links to the resource group

  # IP configuration for the NIC
  ip_configuration {
    name                          = "internal"                        # IP config name
    subnet_id                     = data.azurerm_subnet.vm_subnet.id  # Subnet ID
    private_ip_address_allocation = "Dynamic"                         # Dynamically assign private IP
    public_ip_address_id          = azurerm_public_ip.windows_vm_ip.id  # Associate with a public IP
  }
}

# Define a public IP for the virtual machine
resource "azurerm_public_ip" "windows_vm_ip" {
  name                = "windows-vm-ip"                          # Name of the public IP
  location            = data.azurerm_resource_group.ad.location  # VM location matches the resource group
  resource_group_name = data.azurerm_resource_group.ad.name      # Links to the resource group
  allocation_method   = "Dynamic"                                # Dynamically assign public IP
  sku                 = "Basic"                                  # Use basic SKU
  domain_name_label   = "window-vm-${random_string.vm_suffix.result}"
                                                                 # Unique domain label for the public IP
}

# Define a Windows virtual machine
resource "azurerm_windows_virtual_machine" "windows_ad_instance" {
  name                = "win-ad-${random_string.vm_suffix.result}" # Name of the VM
  location            = data.azurerm_resource_group.ad.location    # VM location matches the resource group
  resource_group_name = data.azurerm_resource_group.ad.name        # Links to the resource group 
  size                = "Standard_DS1_v2"                          # VM size
  admin_username      = "adminuser"                                # Admin username for the VM
  admin_password      = random_password.win_adminuser_password.result

  network_interface_ids = [
    azurerm_network_interface.windows_vm_nic.id                   # Associate NIC with the VM
  ]

  # OS disk configuration
  os_disk {
    caching              = "ReadWrite"                        # Enable read/write caching
    storage_account_type = "Standard_LRS"                     # Standard locally redundant storage
  }

  # Use a Windows Server image from the marketplace
  source_image_reference {
    publisher = "MicrosoftWindowsServer"  # Image publisher
    offer     = "WindowsServer"           # Image offer
    sku       = "2022-Datacenter"         # Windows Server 2022 Datacenter edition
    version   = "latest"                  # Latest version
  }

  # Optionally, enable automatic Windows updates
  patch_mode = "AutomaticByOS"
  enable_automatic_updates = true

  identity {
    type = "SystemAssigned"
  }

}

# Assign the "Key Vault Secrets User" role to the VM's managed identity
resource "azurerm_role_assignment" "vm_win_key_vault_secrets_user" {
  scope                = data.azurerm_key_vault.ad_key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_windows_virtual_machine.windows_ad_instance.identity[0].principal_id
}

resource "azurerm_virtual_machine_extension" "join_script" {
  name                 = "customScript"
  virtual_machine_id   = azurerm_windows_virtual_machine.windows_ad_instance.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
  {
    "fileUris": ["https://${azurerm_storage_account.scripts_storage.name}.blob.core.windows.net/${azurerm_storage_container.scripts.name}/${azurerm_storage_blob.ad_join_script.name}?${data.azurerm_storage_account_sas.script_sas.sas}"],
    "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -File ad-join.ps1"
   }
  SETTINGS
}