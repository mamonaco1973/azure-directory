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
  key_vault_id = data.azurerm_key_vault.ad_key_vault.id
  content_type = "application/json"
}

resource "azuread_user" "mcloud_admin" {
   user_principal_name = "mcloud-admin@${var.azure_domain}"
   display_name        = "mcloud-admin"
   password            = random_password.admin_password.result
}

resource "azurerm_role_assignment" "avd_user_access" {
  scope                = azurerm_virtual_desktop_application_group.avd_app_group.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = azuread_user.mcloud_admin.object_id
}

data "azuread_group" "dc_admins" {
  display_name = "AAD DC Administrators"
}

resource "azuread_group_member" "mcloud_admin_member" {
  group_object_id = data.azuread_group.dc_admins.object_id
  member_object_id = azuread_user.mcloud_admin.object_id
}