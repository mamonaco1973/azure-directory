
# resource "azurerm_resource_provider_registration" "aadds" {
#   name = "Microsoft.AAD"
# }

resource "azurerm_active_directory_domain_service" "aadds" {
  name                = "mikecloud"
  location            = azurerm_resource_group.ad.location
  resource_group_name = azurerm_resource_group.ad.name

  domain_name           = "mcloud.mikecloud.com"
  sku                   = "Standard"

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

#   depends_on = [ azurerm_resource_provider_registration.aadds ]
}