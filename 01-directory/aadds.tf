
# resource "azurerm_resource_provider_registration" "aadds" {
#   name = "Microsoft.AAD"
# }

resource "azuread_group" "dc_admins" {
  display_name     = "AAD DC Administrators"
  description      = "AADDS Administrators"
  members          = [azuread_user.dc_admin.object_id]
  security_enabled = true
}

# Put this in the build script - az ad sp create --id "2565bd9d-da50-47d4-8b85-4c97f669dc36"
# resource "azuread_service_principal" "aadds" {
#   client_id = "2565bd9d-da50-47d4-8b85-4c97f669dc36" 
# }

resource "azuread_user" "dc_admin" {
  user_principal_name = "mcloudAdmin${random_string.unique_id_string.result}@${var.azure_domain}"
  display_name        = "MCLOUD DC Administrator"
  password            = random_password.admin_password.result
}

resource "azurerm_network_security_group" "aadds" {
  name                = "aadds-nsg"
  location            = azurerm_resource_group.ad.location
  resource_group_name = azurerm_resource_group.ad.name

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
    additional_recipients = ["Admin@mikecloud.com"]
    notify_dc_admins      = true
    notify_global_admins  = true
  }

  security {
    sync_kerberos_passwords = true
    sync_ntlm_passwords     = true
    sync_on_prem_passwords  = true
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.aadds
  ]
}

# Update the DNS servers for the existing VNet
resource "azurerm_virtual_network_dns_servers" "example" {
  virtual_network_id = azurerm_virtual_network.ad_vnet.id
  dns_servers        = azurerm_active_directory_domain_service.aadds.initial_replica_set[0].domain_controller_ip_addresses
}