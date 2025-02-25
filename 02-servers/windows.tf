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
  domain_name_label   = "window-vm-${substr(data.azurerm_client_config.current.subscription_id, 0, 6)}" 
                                                                 # Unique domain label for the public IP
}

# Define a Windows virtual machine
resource "azurerm_windows_virtual_machine" "windows_ad_instance" {
  name                = "win-ad-instance"                          # Name of the VM
  location            = data.azurerm_resource_group.ad.location    # VM location matches the resource group
  resource_group_name = data.azurerm_resource_group.ad.name        # Links to the resource group 
  size                = "Standard_DS1_v2"                          # VM size
  admin_username      = "adminuser"                                # Admin username for the VM
  admin_password      = "Password1!"                               # Admin password (Ensure strong password policy)

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

  # Enable Remote Desktop Protocol (RDP)
  enable_automatic_updates = true

  # Custom data for initialization (Base64 encoded PowerShell script)
  custom_data = filebase64("scripts/custom_data.ps1")
}
