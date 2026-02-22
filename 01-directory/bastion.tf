# ==============================================================================
# Azure Bastion Deployment (Conditional)
# ------------------------------------------------------------------------------
# Purpose:
#   - Deploys Azure Bastion only when var.bastion_support == true.
#   - Uses count to conditionally create all Bastion-related resources.
#
# Usage:
#   variable "bastion_support" {
#     type    = bool
#     default = false
#   }
#
# Notes:
#   - When bastion_support = false, no Bastion resources are created.
#   - References to counted resources must use index [0].
# ==============================================================================

# ------------------------------------------------------------------------------
# Network Security Group for Azure Bastion (Conditional)
# ------------------------------------------------------------------------------
resource "azurerm_network_security_group" "bastion-nsg" {
  count               = var.bastion_support ? 1 : 0
  name                = "bastion-nsg"
  location            = azurerm_resource_group.ad.location
  resource_group_name = azurerm_resource_group.ad.name

  security_rule {
    name                       = "GatewayManager"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Internet-Bastion-PublicIP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "OutboundVirtualNetwork"
    priority                   = 1001
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "OutboundToAzureCloud"
    priority                   = 1002
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }
}

# ------------------------------------------------------------------------------
# Subnet: Azure Bastion subnet (Conditional)
# ------------------------------------------------------------------------------
resource "azurerm_subnet" "bastion_subnet" {
  count                = var.bastion_support ? 1 : 0
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.ad.name
  virtual_network_name = azurerm_virtual_network.ad_vnet.name
  address_prefixes     = ["10.0.1.0/25"]
}

# ------------------------------------------------------------------------------
# Public IP for Azure Bastion (Conditional)
# ------------------------------------------------------------------------------
resource "azurerm_public_ip" "bastion-ip" {
  count               = var.bastion_support ? 1 : 0
  name                = "bastion-public-ip"
  location            = azurerm_resource_group.ad.location
  resource_group_name = azurerm_resource_group.ad.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ------------------------------------------------------------------------------
# Azure Bastion Host (Conditional)
# ------------------------------------------------------------------------------
resource "azurerm_bastion_host" "bastion-host" {
  count               = var.bastion_support ? 1 : 0
  name                = "bastion-host"
  location            = azurerm_resource_group.ad.location
  resource_group_name = azurerm_resource_group.ad.name

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.bastion_subnet[0].id
    public_ip_address_id = azurerm_public_ip.bastion-ip[0].id
  }
}