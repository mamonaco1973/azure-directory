# ==============================================================================
# Networking: VNet, Subnets, NSG, and NAT Gateway (Controlled Egress)
# ------------------------------------------------------------------------------
# Purpose:
#   - Creates the primary Virtual Network for the project.
#   - Defines dedicated subnets for:
#       * VM workload subnet (general compute)
#       * AADDS subnet (Azure AD Domain Services placement)
#   - Disables default outbound access on subnets and routes egress through a
#     shared NAT Gateway with a static public IP.
#   - Creates and associates an NSG to the VM subnet for basic admin access.
#
# Notes:
#   - AADDS should be deployed into its own dedicated subnet.
#   - Disabling default outbound access forces explicit egress via NAT Gateway.
#   - The VM NSG rules below allow SSH (22) and RDP (3389) from anywhere, which
#     is convenient for labs but not ideal for production use.
# ==============================================================================

# ------------------------------------------------------------------------------
# Virtual Network: Primary address space for the deployment
# ------------------------------------------------------------------------------
resource "azurerm_virtual_network" "ad_vnet" {
  name                = "ad-vnet"
  address_space       = ["10.0.0.0/23"]
  location            = azurerm_resource_group.ad.location
  resource_group_name = azurerm_resource_group.ad.name
}

# ------------------------------------------------------------------------------
# Subnet: General VM workload subnet
# ------------------------------------------------------------------------------
resource "azurerm_subnet" "vm_subnet" {
  name                                = "vm-subnet"
  resource_group_name                 = azurerm_resource_group.ad.name
  virtual_network_name                = azurerm_virtual_network.ad_vnet.name
  address_prefixes                    = ["10.0.0.0/25"]
  default_outbound_access_enabled     = false
}

# ------------------------------------------------------------------------------
# Subnet: Azure AD Domain Services subnet (dedicated placement)
# ------------------------------------------------------------------------------
resource "azurerm_subnet" "aadds_subnet" {
  name                                = "aadds-subnet"
  resource_group_name                 = azurerm_resource_group.ad.name
  virtual_network_name                = azurerm_virtual_network.ad_vnet.name
  address_prefixes                    = ["10.0.0.128/25"]
  default_outbound_access_enabled     = false
}

# ------------------------------------------------------------------------------
# Network Security Group: VM subnet traffic controls
# ------------------------------------------------------------------------------
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "vm-nsg"
  location            = azurerm_resource_group.ad.location
  resource_group_name = azurerm_resource_group.ad.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-RDP"
    priority                   = "1002"
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ------------------------------------------------------------------------------
# Association: Attach VM NSG to the VM subnet
# ------------------------------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "vm-nsg-assoc" {
  subnet_id                 = azurerm_subnet.vm_subnet.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

# ------------------------------------------------------------------------------
# NAT Gateway: Public IP, Gateway, and Associations
# ------------------------------------------------------------------------------
# Provides controlled outbound internet access for private subnet workloads.
# ------------------------------------------------------------------------------
resource "azurerm_public_ip" "nat_gateway_pip" {
  name                = "nat-gateway-pip"
  location            = azurerm_resource_group.ad.location
  resource_group_name = azurerm_resource_group.ad.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "vm_nat_gateway" {
  name                    = "vm-nat-gateway"
  location                = azurerm_resource_group.ad.location
  resource_group_name     = azurerm_resource_group.ad.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}

resource "azurerm_nat_gateway_public_ip_association" "nat_gw_pip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.vm_nat_gateway.id
  public_ip_address_id = azurerm_public_ip.nat_gateway_pip.id
}

resource "azurerm_subnet_nat_gateway_association" "vm_nat_assoc" {
  subnet_id      = azurerm_subnet.vm_subnet.id
  nat_gateway_id = azurerm_nat_gateway.vm_nat_gateway.id
}

resource "azurerm_subnet_nat_gateway_association" "aadds_nat_assoc" {
  subnet_id      = azurerm_subnet.aadds_subnet.id
  nat_gateway_id = azurerm_nat_gateway.vm_nat_gateway.id
}