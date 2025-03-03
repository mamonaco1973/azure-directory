
# These two settings were moved to ./check_env.sh 
# Letting terraform manage these settings causes problems when
# destroying the project 

# resource "azurerm_resource_provider_registration" "aadds" {
#   name = "Microsoft.AAD"
# }

# Put this in the build script - az ad sp create --id "2565bd9d-da50-47d4-8b85-4c97f669dc36"
# resource "azuread_service_principal" "aadds" {
#   client_id = "2565bd9d-da50-47d4-8b85-4c97f669dc36" 
# }

resource "azurerm_network_security_group" "aadds" {
  name                = "aadds-nsg"
  location            = azurerm_resource_group.ad.location
  resource_group_name = azurerm_resource_group.ad.name

  security_rule {
    name                       = "AllowSyncWithAzureAD"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureActiveDirectoryDomainServices"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowRD"
    priority                   = 201
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "CorpNetSaw"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowPSRemoting"
    priority                   = 301
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5986"
    source_address_prefix      = "AzureActiveDirectoryDomainServices"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowLDAPS"
    priority                   = 401
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "636"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource azurerm_subnet_network_security_group_association "aadds" {
  subnet_id                 = azurerm_subnet.aadds_subnet.id
  network_security_group_id = azurerm_network_security_group.aadds.id
}

resource "azurerm_active_directory_domain_service" "aadds" {
  name                = "mikecloud"
  location            = azurerm_resource_group.ad.location
  resource_group_name = azurerm_resource_group.ad.name

  domain_name               = "mcloud.mikecloud.com"
  sku                       = "Standard"
  domain_configuration_type = "FullySynced" 

  initial_replica_set {
    subnet_id = azurerm_subnet.aadds_subnet.id
  }

  notifications {
    additional_recipients = ["mcloud-admin@${var.azure_domain}"]
    notify_dc_admins      = true
    notify_global_admins  = true
  }

  security {
    sync_kerberos_passwords = true
    sync_ntlm_passwords     = true
    sync_on_prem_passwords  = true
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.aadds,
    azurerm_subnet_network_security_group_association.vm-nsg-assoc
  ]
}

# Update the DNS servers for the existing VNet
resource "azurerm_virtual_network_dns_servers" "aadds_dns_servers" {
  virtual_network_id = azurerm_virtual_network.ad_vnet.id
  dns_servers        = azurerm_active_directory_domain_service.aadds.initial_replica_set[0].domain_controller_ip_addresses
}
