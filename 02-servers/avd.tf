resource "azurerm_virtual_desktop_host_pool" "avd_host_pool" {
  name                = "avd-host-pool"
  location            = data.azurerm_resource_group.ad.location
  resource_group_name = data.azurerm_resource_group.ad.name
  type                = "Pooled"
  load_balancer_type  = "BreadthFirst"
  preferred_app_group_type = "Desktop"
  start_vm_on_connect = true
  validate_environment = true
}

resource "azurerm_virtual_desktop_application_group" "avd_app_group" {
  name                = "avd-desktop-appgroup"
  location            = data.azurerm_resource_group.ad.location
  resource_group_name = data.azurerm_resource_group.ad.name
  host_pool_id        = azurerm_virtual_desktop_host_pool.avd_host_pool.id
  type                = "Desktop"
  friendly_name       = "AVD Desktop AppGroup"
}

resource "azurerm_virtual_desktop_workspace" "avd_workspace" {
  name                = "avd-workspace"
  location            = data.azurerm_resource_group.ad.location
  resource_group_name = data.azurerm_resource_group.ad.name
  friendly_name       = "AVD Workspace"
  description         = "Workspace for AVD desktops"
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "avd_workspace_assoc" {
  workspace_id         = azurerm_virtual_desktop_workspace.avd_workspace.id
  application_group_id = azurerm_virtual_desktop_application_group.avd_app_group.id
}

resource "azurerm_role_assignment" "avd_user_access" {
  scope                = azurerm_virtual_desktop_application_group.avd_app_group.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = azuread_user.mcloud_admin.object_id
}