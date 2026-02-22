# ==============================================================================
# Azure Key Vault: Naming, Creation, and RBAC Access
# ------------------------------------------------------------------------------
# Purpose:
#   - Creates an Azure Key Vault to store secrets used by this deployment
#     (e.g., generated admin/user credentials, bootstrap tokens, etc.).
#   - Uses RBAC authorization (not access policies) for secret management.
#   - Assigns the current Terraform caller a role permitting secret operations.
#
# Notes:
#   - The random suffix ensures the Key Vault name is globally unique.
#   - purge_protection_enabled is disabled to keep lab/project teardown simple.
#   - RBAC authorization must be enabled for role assignments to control access.
# ==============================================================================

# ------------------------------------------------------------------------------
# Random Suffix: Key Vault names must be globally unique in Azure
# ------------------------------------------------------------------------------
resource "random_string" "key_vault_suffix" {
  length  = 8
  special = false
  upper   = false
}

# ------------------------------------------------------------------------------
# Key Vault: Central secret store for the deployment
# ------------------------------------------------------------------------------
resource "azurerm_key_vault" "ad_key_vault" {
  name                       = "ad-key-vault-${random_string.key_vault_suffix.result}"
  resource_group_name        = azurerm_resource_group.ad.name
  location                   = azurerm_resource_group.ad.location
  sku_name                   = "standard"
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled   = false
  rbac_authorization_enabled = true
}

# ------------------------------------------------------------------------------
# RBAC: Allow the current Terraform identity to manage Key Vault secrets
# ------------------------------------------------------------------------------
# Grants the caller permissions to create/read/update/delete secrets in the vault.
# This role assignment is commonly used as a dependency for secret resources.
# ------------------------------------------------------------------------------
resource "azurerm_role_assignment" "kv_role_assignment" {
  scope                = azurerm_key_vault.ad_key_vault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}