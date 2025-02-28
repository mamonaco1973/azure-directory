resource "azurerm_storage_account" "scripts_storage" {
  name                     = "vmscripts${random_string.storage_name.result}"
  resource_group_name      = data.azurerm_resource_group.ad.name
  location                 = data.azurerm_resource_group.ad.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "scripts" {
  name                  = "scripts"
  storage_account_id    = azurerm_storage_account.scripts_storage.id
  container_access_type = "private"
}

# Inject variables into the PowerShell script template
locals {
  ad_join_script = templatefile("./scripts/ad_join.ps1.template", {
    vault_name  = data.azurerm_key_vault.ad_key_vault.name
    domain_fqdn = "mcloud.mikecloud.com"
  })
}

resource "local_file" "ad_join_rendered" {
  filename = "./scripts/ad_join.ps1"
  content  = local.ad_join_script
}

resource "azurerm_storage_blob" "ad_join_script" {
  name                   = "ad-join.ps1"
  storage_account_name   = azurerm_storage_account.scripts_storage.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = local_file.ad_join_rendered.filename
}

resource "random_string" "storage_name" {
  length  = 10
  upper   = false
  special = false
  numeric = true
}

data "azurerm_storage_account_sas" "script_sas" {
  connection_string = azurerm_storage_account.scripts_storage.primary_connection_string

  resource_types {
    service   = false
    container = false
    object    = true
  }

  services {
    blob   = true
    queue  = false
    table  = false
    file   = false
  }

  start  = formatdate("YYYY-MM-DD'T'HH:mm:ss'Z'", timestamp())
  expiry = formatdate("YYYY-MM-DD'T'HH:mm:ss'Z'", timeadd(timestamp(), "24h"))

  permissions {
    read    = true
    write   = false
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
    filter  = false
    tag     = false
  }
}


#output "ad_join_script_url" {
#  description = "The URL to the AD Join script including SAS token"
#  value = "https://${azurerm_storage_account.scripts_storage.name}.blob.core.windows.net/${azurerm_storage_container.scripts.name}/${azurerm_storage_blob.ad_join_script.name}${data.azurerm_storage_account_sas.script_sas.sas}"

#  value       = "https://${azurerm_storage_account.scripts_storage.name}.blob.core.windows.net/${azurerm_storage_container.scripts.name}/${azurerm_storage_blob.ad_join_script.name}?${data.azurerm_storage_account_sas.script_sas.sas}"
#  sensitive = true
#}
