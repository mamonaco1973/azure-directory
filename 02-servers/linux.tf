
# --- User: ubuntu ---

# Generate a random password for "ubuntu"
resource "random_password" "ubuntu_password" {
  length             = 24
  special            = true
  override_special   = "!@#$%"
}

# Create secret for local linux ubuntu account

resource "azurerm_key_vault_secret" "ubuntu_secret" {
  name         = "ubuntu-credentials"
  value        = jsonencode({
    username = "ubuntu"
    password = random_password.ubuntu_password.result
  })
  key_vault_id = data.azurerm_key_vault.ad_key_vault.id
  content_type = "application/json"
}

# Define a network interface to connect the VM to the network
resource "azurerm_network_interface" "linux_vm_nic" {
  name                = "linux-vm-nic"                            # Name of the NIC
  location            = data.azurerm_resource_group.ad.location   # VM location matches the resource group
  resource_group_name = data.azurerm_resource_group.ad.name       # Links to the resource group

  # IP configuration for the NIC
  ip_configuration {
    name                          = "internal"                        # IP config name
    subnet_id                     = data.azurerm_subnet.vm_subnet.id  # Subnet ID
    private_ip_address_allocation = "Dynamic"                         # Dynamically assign private IP
    public_ip_address_id          = azurerm_public_ip.linux_vm_ip.id  # Associate with a public IP
  }
}

# Define a public IP for the virtual machine
resource "azurerm_public_ip" "linux_vm_ip" {
  name                = "linux-vm-ip"                            # Name of the public IP
  location            = data.azurerm_resource_group.ad.location  # VM location matches the resource group
  resource_group_name = data.azurerm_resource_group.ad.name      # Links to the resource group
  allocation_method   = "Dynamic"                                # Dynamically assign public IP
  sku                 = "Basic"                                  # Use basic SKU
  domain_name_label   = "linux-vm-${substr(data.azurerm_client_config.current.subscription_id, 0, 6)}" 
                                                                 # Unique domain label for the public IP
}

# Define a Linux virtual machine
resource "azurerm_linux_virtual_machine" "linux_ad_instance" {
  name                = "linux-ad-instance"                       # Name of the VM
  location            =  data.azurerm_resource_group.ad.location  # VM location matches the resource group
  resource_group_name = data.azurerm_resource_group.ad.name       # Links to the resource group
  size                = "Standard_B1s"                            # VM size
  admin_username      = "ubuntu"                                  # Admin username for the VM
  admin_password      = random_password.ubuntu_password.result
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.linux_vm_nic.id                     # Associate NIC with the VM
  ]

  # OS disk configuration
  os_disk {
    caching              = "ReadWrite"                        # Enable read/write caching
    storage_account_type = "Standard_LRS"                     # Standard locally redundant storage
  }

  # Use an Ubuntu image from the marketplace
  source_image_reference {
    publisher = "canonical"                          # Image publisher
    offer     = "ubuntu-24_04-lts"                   # Image offer
    sku       = "server"                             # Image SKU
    version   = "latest"                             # Latest version
  }

  # Pass custom data to the VM (e.g., initialization script)
  custom_data = filebase64("scripts/custom_data.sh")

  identity {
    type = "SystemAssigned"
  }
}


# Assign the "Key Vault Secrets User" role to the VM's managed identity
resource "azurerm_role_assignment" "vm_lnx_key_vault_secrets_user" {
  scope                = data.azurerm_key_vault.ad_key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         =  azurerm_linux_virtual_machine.linux_ad_instance.identity[0].principal_id
}