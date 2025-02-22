resource "random_string" "key_vault_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Create an Azure Key Vault
resource "azurerm_key_vault" "ad_key_vault" {
  name                        = "ad-key-vault-${random_string.key_vault_suffix.result}"  
  resource_group_name         = azurerm_resource_group.ad.name
  location                    = azurerm_resource_group.ad.location
  sku_name                    = "standard"
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled    = false
  enable_rbac_authorization   = true
}

# Assign RBAC role to the current client for managing secrets
resource "azurerm_role_assignment" "kv_role_assignment" {
  scope                = azurerm_key_vault.ad_key_vault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}
