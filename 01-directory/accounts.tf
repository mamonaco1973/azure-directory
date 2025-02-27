# Generate a random password for the Active Directory (AD) Administrator
resource "random_password" "admin_password" {
  length             = 24    # Set password length to 24 characters
  special            = true  # Include special characters in the password
  override_special   = "!@#$%" # Limit special characters to this set
}

# Create a Key Vault secret for the AD Admin credentials
resource "azurerm_key_vault_secret" "admin_secret" {
  name         = "admin-ad-credentials"
  value        = jsonencode({
    username = "mcloud-admin@${var.azure_domain}"
    password = random_password.admin_password.result
  })
  key_vault_id = azurerm_key_vault.ad_key_vault.id
  depends_on = [ azurerm_role_assignment.kv_role_assignment ]
  content_type = "application/json"
}

# --- User: John Smith ---

# Generate a random password for John Smith
resource "random_password" "jsmith_password" {
  length             = 24
  special            = true
  override_special   = "!@#$%"
}

# Create secret for John Smith's credentials

resource "azurerm_key_vault_secret" "jsmith_secret" {
  name         = "jsmith-ad-credentials"
  value        = jsonencode({
    username = "MCLOUD\\jsmith"
    password = random_password.jsmith_password.result
  })
  key_vault_id = azurerm_key_vault.ad_key_vault.id
  depends_on = [ azurerm_role_assignment.kv_role_assignment ]
  content_type = "application/json"
}

# --- User: Emily Davis ---

# Generate a random password for Emily Davis
resource "random_password" "edavis_password" {
  length             = 24
  special            = true
  override_special   = "!@#$%"
}

# Create secret for Emily Davis' credentials

resource "azurerm_key_vault_secret" "edavis_secret" {
  name         = "edavis-ad-credentials"
  value        = jsonencode({
    username = "MCLOUD\\edavis"
    password = random_password.edavis_password.result
  })
  key_vault_id = azurerm_key_vault.ad_key_vault.id
  depends_on = [ azurerm_role_assignment.kv_role_assignment ]
  content_type = "application/json"
}

# --- User: Raj Patel ---

# Generate a random password for Raj Patel
resource "random_password" "rpatel_password" {
  length             = 24
  special            = true
  override_special   = "!@#$%"
}

# Create secret for Raj Patel's credentials

resource "azurerm_key_vault_secret" "rpatel_secret" {
  name         = "rpatel-ad-credentials"
  value        = jsonencode({
    username = "MCLOUD\\rpatel"
    password = random_password.rpatel_password.result
  })
  key_vault_id = azurerm_key_vault.ad_key_vault.id
  depends_on = [ azurerm_role_assignment.kv_role_assignment ]
  content_type = "application/json"
}

# --- User: Amit Kumar ---

# Generate a random password for Amit Kumar
resource "random_password" "akumar_password" {
  length             = 24
  special            = true
  override_special   = "!@#$%"
}

# Create secret for Amit Kumar's credentials

resource "azurerm_key_vault_secret" "akumar_secret" {
  name         = "akumar-ad-credentials"
  value        = jsonencode({
    username = "MCLOUD\\akumar"
    password = random_password.akumar_password.result
  })
  key_vault_id = azurerm_key_vault.ad_key_vault.id
  depends_on = [ azurerm_role_assignment.kv_role_assignment ]
  content_type = "application/json"
}

