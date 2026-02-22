# ==============================================================================
# Active Directory User Credential Secrets
# ------------------------------------------------------------------------------
# Purpose:
#   - Generates strong, per-user random passwords.
#   - Stores each user's domain credentials as JSON in Azure Key Vault.
#
# Output / Storage Format:
#   - Secret value is a JSON object:
#       {
#         "username": "MCLOUD\\<user>",
#         "password": "<generated>"
#       }
#
# Notes:
#   - These resources do NOT create AD users. They only generate and store
#     credentials for use by bootstrap / provisioning scripts.
#   - The Key Vault secret writes depend on the Key Vault role assignment so
#     Terraform has permission to set secrets.
#   - override_special constrains the special characters to a known-safe set
#     for downstream consumers (scripts, AD tooling, JSON parsing, etc.).
# ==============================================================================

# ------------------------------------------------------------------------------
# User: John Smith (jsmith)
# ------------------------------------------------------------------------------
# Generates a random password and stores the resulting credentials in Key Vault.
# ------------------------------------------------------------------------------
resource "random_password" "jsmith_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

resource "azurerm_key_vault_secret" "jsmith_secret" {
  name = "jsmith-ad-credentials"
  value = jsonencode({
    username = "MCLOUD\\jsmith"
    password = random_password.jsmith_password.result
  })
  key_vault_id  = azurerm_key_vault.ad_key_vault.id
  depends_on    = [azurerm_role_assignment.kv_role_assignment]
  content_type  = "application/json"
}

# ------------------------------------------------------------------------------
# User: Emily Davis (edavis)
# ------------------------------------------------------------------------------
# Generates a random password and stores the resulting credentials in Key Vault.
# ------------------------------------------------------------------------------
resource "random_password" "edavis_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

resource "azurerm_key_vault_secret" "edavis_secret" {
  name = "edavis-ad-credentials"
  value = jsonencode({
    username = "MCLOUD\\edavis"
    password = random_password.edavis_password.result
  })
  key_vault_id  = azurerm_key_vault.ad_key_vault.id
  depends_on    = [azurerm_role_assignment.kv_role_assignment]
  content_type  = "application/json"
}

# ------------------------------------------------------------------------------
# User: Raj Patel (rpatel)
# ------------------------------------------------------------------------------
# Generates a random password and stores the resulting credentials in Key Vault.
# ------------------------------------------------------------------------------
resource "random_password" "rpatel_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

resource "azurerm_key_vault_secret" "rpatel_secret" {
  name = "rpatel-ad-credentials"
  value = jsonencode({
    username = "MCLOUD\\rpatel"
    password = random_password.rpatel_password.result
  })
  key_vault_id  = azurerm_key_vault.ad_key_vault.id
  depends_on    = [azurerm_role_assignment.kv_role_assignment]
  content_type  = "application/json"
}

# ------------------------------------------------------------------------------
# User: Amit Kumar (akumar)
# ------------------------------------------------------------------------------
# Generates a random password and stores the resulting credentials in Key Vault.
# ------------------------------------------------------------------------------
resource "random_password" "akumar_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

resource "azurerm_key_vault_secret" "akumar_secret" {
  name = "akumar-ad-credentials"
  value = jsonencode({
    username = "MCLOUD\\akumar"
    password = random_password.akumar_password.result
  })
  key_vault_id  = azurerm_key_vault.ad_key_vault.id
  depends_on    = [azurerm_role_assignment.kv_role_assignment]
  content_type  = "application/json"
}