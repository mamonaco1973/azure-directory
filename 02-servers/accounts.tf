# ==============================================================================
# Azure AD Domain Admin Bootstrap Module
# ------------------------------------------------------------------------------
# Purpose:
#   - Generates a strong password for the managed domain administrator.
#   - Creates a unique Azure AD admin user per deployment to avoid AAD soft-delete
#     / eventual consistency collisions during rapid rebuild cycles.
#   - Stores administrator credentials securely in Azure Key Vault as JSON.
#   - Adds the user to the "AAD DC Administrators" group required for AADDS.
#
# Notes:
#   - Azure AD user objects are often soft-deleted and may not be reusable
#     immediately. Using a unique UPN per run avoids conflicts when builds are
#     executed back-to-back.
#   - Password is generated once and reused for:
#       * Azure AD user creation
#       * Key Vault secret storage
#   - The Key Vault secret is stored as JSON for easy consumption by automation.
# ==============================================================================
#
# Outputs / Contracts:
#   - Secret name: admin-ad-credentials
#   - Secret JSON: { "username": "<upn>", "password": "<password>" }
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
# Random ID: Unique Suffix for Admin UPN
# ------------------------------------------------------------------------------
# Ensures the Azure AD user principal name is unique per build to avoid conflicts
# with soft-deleted users during rapid destroy/apply cycles.
# ------------------------------------------------------------------------------
resource "random_id" "admin_suffix" {
  byte_length = 3
}

# ------------------------------------------------------------------------------
# Locals: Admin Identity
# ------------------------------------------------------------------------------
# Builds a unique UPN while keeping display_name consistent for readability.
# Example UPN:
#   mcloud-admin-a1b2c3@contoso.onmicrosoft.com
# ------------------------------------------------------------------------------
locals {
  admin_upn          = "mcloud-admin-${random_id.admin_suffix.hex}@${var.azure_domain}"
  admin_display_name = "mcloud-admin"
  admin_secret_name  = "admin-ad-credentials"
}

# ------------------------------------------------------------------------------
# Azure AD User: Managed Domain Administrator Account
# ------------------------------------------------------------------------------
# Creates the cloud identity that will become an AADDS domain administrator.
# ------------------------------------------------------------------------------
resource "azuread_user" "mcloud_admin" {
  user_principal_name = local.admin_upn
  display_name        = local.admin_display_name
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

# ------------------------------------------------------------------------------
# Key Vault Secret: AD Admin Credentials
# ------------------------------------------------------------------------------
# Stores the administrator username/password as a JSON object.
# Username format matches Azure AD UPN.
# ------------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "admin_secret" {
  name = local.admin_secret_name
  value = jsonencode({
    username = local.admin_upn
    password = random_password.admin_password.result
  })
  key_vault_id = data.azurerm_key_vault.ad_key_vault.id
  content_type = "application/json"
}