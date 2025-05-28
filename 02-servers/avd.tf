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

resource "azurerm_virtual_desktop_host_pool_registration_info" "token" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.avd_host_pool.id
  expiration_date = timeadd(timestamp(), "24h")
}

resource "azurerm_network_interface" "avd_nic" {
  count               = var.session_host_count
  name                = "avd-nic-${count.index}"
  location            = data.azurerm_resource_group.ad.location
  resource_group_name = data.azurerm_resource_group.ad.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "avd_session_host" {
  count               = var.session_host_count
  name                = "avd-session-${count.index}"
  location            = data.azurerm_resource_group.ad.location
  resource_group_name = data.azurerm_resource_group.ad.name
  size                = "Standard_D2s_v3"
  admin_username      = "adminuser"                                
  admin_password      = random_password.win_adminuser_password.result 

  network_interface_ids = [azurerm_network_interface.avd_nic[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-22h2-avd"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Role = "AVD-SessionHost"
  }
}

variable "session_host_count" {
  type        = number
  default     = 1
  description = "Number of AVD session host VMs to deploy"
}


resource "azurerm_role_assignment" "sessionhost_key_vault_secrets_user" {
  count                = var.session_host_count
  scope                = data.azurerm_key_vault.ad_key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_windows_virtual_machine.avd_session_host[count.index].identity[0].principal_id
}


# resource "azurerm_virtual_machine_extension" "register_avd_host" {
#   count               = var.session_host_count
#   name                = "register-avd-host-${count.index}"
#   virtual_machine_id  = azurerm_windows_virtual_machine.avd_session_host[count.index].id
#   publisher           = "Microsoft.Compute"
#   type                = "CustomScriptExtension"
#   type_handler_version = "1.10"

#   settings = jsonencode({
#     "commandToExecute" = "powershell.exe -ExecutionPolicy Bypass -Command \"Register-RDAgent -Token '${azurerm_virtual_desktop_host_pool_registration_info.token.token}'\""
#   })

#   depends_on = [azurerm_windows_virtual_machine.avd_session_host]
# }

# resource "azurerm_virtual_machine_extension" "join_domain" {
#   count               = var.session_host_count
#   name                = "domain-join-${count.index}"
#   virtual_machine_id  = azurerm_windows_virtual_machine.avd_session_host[count.index].id
#   publisher           = "Microsoft.Compute"
#   type                = "CustomScriptExtension"
#   type_handler_version = "1.10"

#   settings = jsonencode({
#     fileUris = [
#       "https://${azurerm_storage_account.scripts_storage.name}.blob.core.windows.net/${azurerm_storage_container.scripts.name}/${azurerm_storage_blob.ad_join_script.name}?${data.azurerm_storage_account_sas.script_sas.sas}"
#     ],
#     commandToExecute = "powershell.exe -ExecutionPolicy Unrestricted -File ad-join.ps1 *>> C:\\WindowsAzure\\Logs\\ad-join.log"
#   })

#   depends_on = [azurerm_windows_virtual_machine.avd_session_host]
# }

