resource "azurerm_storage_account" "scripts_storage" {
  name                     = "vmscripts${random_string.storage_name.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
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