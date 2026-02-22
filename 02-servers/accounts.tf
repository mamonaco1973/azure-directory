# ==============================================================================
# Azure AD Domain Admin Bootstrap Module
# ------------------------------------------------------------------------------
# Purpose:
#   - Generates a strong password for the managed domain administrator.
#   - Stores administrator credentials securely in Azure Key Vault.
#   - Creates an Azure AD user for the managed domain admin account.
#   - Adds the user to the "AAD DC Administrators" group required for AADDS.
#
# Notes:
#   - The Azure AD user must exist and be a member of "AAD DC Administrators"
#     before Azure AD Domain Services (AADDS) can grant domain admin rights.
#   - Password is generated once and reused for:
#       * Azure AD user creation
#       * Key Vault secret storage
#   - The Key Vault secret is stored as JSON for easy consumption by
#     automation scripts (cloud-init, bootstrap scripts, etc.).
# ==============================================================================

# ------------------------------------------------------------------------------
# Random Password: Managed Domain Administrator
# ------------------------------------------------------------------------------
# Generates a strong 24-character password including limited special chars.
# override_special constrains characters to avoid downstream parsing issues.
# ------------------------------------------------------------------------------
resource "random_password" "admin_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# ------------------------------------------------------------------------------
# Key Vault Secret: AD Admin Credentials
# ------------------------------------------------------------------------------
# Stores the administrator username/password as a JSON object.
# Username format matches Azure AD UPN.
# ------------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "admin_secret" {
  name = "admin-ad-credentials"
  value = jsonencode({
    username = "mcloud-admin@${var.azure_domain}"
    password = random_password.admin_password.result
  })
  key_vault_id = data.azurerm_key_vault.ad_key_vault.id
  content_type = "application/json"
}

# ------------------------------------------------------------------------------
# Azure AD User: Managed Domain Administrator Account
# ------------------------------------------------------------------------------
# Creates the cloud identity that will become an AADDS domain administrator.
# ------------------------------------------------------------------------------
resource "azuread_user" "mcloud_admin" {
  user_principal_name = "mcloud-admin@${var.azure_domain}"
  display_name        = "mcloud-admin"
  password            = random_password.admin_password.result
}

# ------------------------------------------------------------------------------
# Data Source: AAD DC Administrators Group
# ------------------------------------------------------------------------------
# Built-in Azure AD group required for delegated AADDS domain admin access.
# ------------------------------------------------------------------------------
data "azuread_group" "dc_admins" {
  display_name = "AAD DC Administrators"
}

# ------------------------------------------------------------------------------
# Group Membership: Grant Domain Admin Rights
# ------------------------------------------------------------------------------
# Adds the newly created user to the AAD DC Administrators group.
# This step is required before deploying or managing AADDS.
# ------------------------------------------------------------------------------
resource "azuread_group_member" "mcloud_admin_member" {
  group_object_id  = data.azuread_group.dc_admins.object_id
  member_object_id = azuread_user.mcloud_admin.object_id
}