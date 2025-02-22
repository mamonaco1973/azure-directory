# Define a virtual network for the project
resource "azurerm_virtual_network" "ad_vnet" {
  name                = "ad-vnet"                             # Name of the VNet
  address_space       = ["10.0.0.0/16"]                       # IP address range for the VNet
  location            = azurerm_resource_group.ad.location    # VNet location matches the resource group
  resource_group_name = azurerm_resource_group.ad.name        # Links to the resource group
}

# Define a subnet within the virtual network
resource "azurerm_subnet" "aadds_subnet" {
  name                 = "aadds-subnet"                          # Name of the subnet
  resource_group_name  = azurerm_resource_group.ad.name       # Links to the resource group
  virtual_network_name = azurerm_virtual_network.ad_vnet.name # Links to the VNet
  address_prefixes     = ["10.0.1.0/24"]                      # IP range for the subnet
}

