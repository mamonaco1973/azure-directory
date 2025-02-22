# Configure the AzureRM provider
provider "azurerm" {
  # Enables the default features of the provider
  features {}
}

# Data source to fetch details of the primary subscription
data "azurerm_subscription" "primary" {}

# Data source to fetch the details of the current Azure client
data "azurerm_client_config" "current" {}

# Define a resource group for all resources in this setup
resource "azurerm_resource_group" "setup" {
  name     = "setup-resource-group" # Name of the resource group
  location = "Central US"           # Region where resources will be deployed
}

# Define a virtual network for the setup
resource "azurerm_virtual_network" "setup" {
  name                = "setup-vnet"                          # Name of the VNet
  address_space       = ["10.0.0.0/16"]                       # IP address range for the VNet
  location            = azurerm_resource_group.setup.location # VNet location matches the resource group
  resource_group_name = azurerm_resource_group.setup.name     # Links to the resource group
}

# Define a subnet within the virtual network
resource "azurerm_subnet" "setup" {
  name                 = "setup-subnet"                       # Name of the subnet
  resource_group_name  = azurerm_resource_group.setup.name    # Links to the resource group
  virtual_network_name = azurerm_virtual_network.setup.name   # Links to the VNet
  address_prefixes     = ["10.0.1.0/24"]                      # IP range for the subnet
}

# Define a network security group (NSG) for controlling traffic
resource "azurerm_network_security_group" "setup" {
  name                = "setup-nsg"                           # Name of the NSG
  location            = azurerm_resource_group.setup.location # NSG location matches the resource group
  resource_group_name = azurerm_resource_group.setup.name     # Links to the resource group

  # Security rule to allow SSH traffic
  security_rule {
    name                       = "Allow-SSH"            # Rule name
    priority                   = 1001                   # Priority of the rule
    direction                  = "Inbound"              # Inbound traffic
    access                     = "Allow"                # Allow traffic
    protocol                   = "Tcp"                  # TCP protocol
    source_port_range          = "*"                    # Any source port
    destination_port_range     = "22"                   # Destination port for SSH
    source_address_prefix      = "*"                    # Allow traffic from all IPs
    destination_address_prefix = "*"                    # Applies to all destinations
  }
  
  # Security rule to allow HTTP traffic
  security_rule {
    name                       = "Allow-HTTP"            # Rule name
    priority                   = 1002                    # Priority of the rule
    direction                  = "Inbound"               # Inbound traffic
    access                     = "Allow"                 # Allow traffic
    protocol                   = "Tcp"                   # TCP protocol
    source_port_range          = "*"                     # Any source port
    destination_port_range     = "80"                    # Destination port for HTTP
    source_address_prefix      = "*"                     # Allow traffic from all IPs
    destination_address_prefix = "*"                     # Applies to all destinations
  }
}

# Define a network interface to connect the VM to the network
resource "azurerm_network_interface" "setup" {
  name                = "setup-nic"                           # Name of the NIC
  location            = azurerm_resource_group.setup.location # NIC location matches the resource group
  resource_group_name = azurerm_resource_group.setup.name     # Links to the resource group

  # IP configuration for the NIC
  ip_configuration {
    name                          = "internal"                 # IP config name
    subnet_id                     = azurerm_subnet.setup.id    # Subnet ID
    private_ip_address_allocation = "Dynamic"                  # Dynamically assign private IP
    public_ip_address_id          = azurerm_public_ip.setup.id # Associate with a public IP
  }
}

# Define a public IP for the virtual machine
resource "azurerm_public_ip" "setup" {
  name                = "setup-pip"                           # Name of the public IP
  location            = azurerm_resource_group.setup.location # Public IP location matches the resource group
  resource_group_name = azurerm_resource_group.setup.name     # Links to the resource group
  allocation_method   = "Dynamic"                             # Dynamically assign public IP
  sku                 = "Basic"                               # Use basic SKU
  domain_name_label   = "setup-vm-${substr(data.azurerm_client_config.current.subscription_id, 0, 6)}" 
                                                              # Unique domain label for the public IP
}

# Define a Linux virtual machine
resource "azurerm_linux_virtual_machine" "setup" {
  name                = "setup-vm"                            # Name of the VM
  location            = azurerm_resource_group.setup.location # VM location matches the resource group
  resource_group_name = azurerm_resource_group.setup.name     # Links to the resource group
  size                = "Standard_B1s"                        # VM size
  admin_username      = "ubuntu"                              # Admin username for the VM
  network_interface_ids = [
    azurerm_network_interface.setup.id                        # Associate NIC with the VM
  ]

  # Configure SSH key for VM access
  admin_ssh_key {
    username   = "ubuntu"                                     # Username for SSH access
    public_key = file("keys/Public_Key")                      # Public key file path
  }

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
}

# Output the public FQDN of the virtual machine
output "vm_public_fqdn" {
  value       = azurerm_public_ip.setup.fqdn         # FQDN of the public IP
  description = "The DNS name of the public IP address"
}
