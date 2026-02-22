# ==============================================================================
# Storage: Script Staging (PowerShell AD Join)
# ------------------------------------------------------------------------------
# Purpose:
#   - Creates a dedicated Azure Storage Account + private container to stage
#     deployment scripts.
#   - Renders a PowerShell script from a template (injecting environment values),
#     writes it locally, then uploads it as a blob.
#   - Generates a short-lived SAS token allowing read-only access to the blob.
#
# Notes:
#   - Storage Account names must be globally unique and use lower-case letters
#     and numbers only; random_string is used to ensure uniqueness.
#   - The blob metadata "force_update" includes timestamp() to force Terraform
#     to re-upload even when the local content does not appear to change.
#   - SAS start time is set 24 hours in the past to reduce clock-skew issues.
# ==============================================================================

# ------------------------------------------------------------------------------
# Random Suffix: Storage Account name uniqueness
# ------------------------------------------------------------------------------
resource "random_string" "storage_name" {
  length  = 10
  upper   = false
  special = false
  numeric = true
}

# ------------------------------------------------------------------------------
# Storage Account: Holds staged deployment scripts
# ------------------------------------------------------------------------------
resource "azurerm_storage_account" "scripts_storage" {
  name                     = "vmscripts${random_string.storage_name.result}"
  resource_group_name      = data.azurerm_resource_group.ad.name
  location                 = data.azurerm_resource_group.ad.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# ------------------------------------------------------------------------------
# Storage Container: Private container for scripts
# ------------------------------------------------------------------------------
resource "azurerm_storage_container" "scripts" {
  name                  = "scripts"
  storage_account_id    = azurerm_storage_account.scripts_storage.id
  container_access_type = "private"
}

# ------------------------------------------------------------------------------
# Locals: Render AD join PowerShell script from template
# ------------------------------------------------------------------------------
# templatefile() injects runtime values into ./scripts/ad_join.ps1.template and
# produces the final script content as a local variable.
# ------------------------------------------------------------------------------
locals {
  ad_join_script = templatefile("./scripts/ad_join.ps1.template", {
    vault_name  = data.azurerm_key_vault.ad_key_vault.name
    domain_fqdn = "mcloud.mikecloud.com"
  })
}

# ------------------------------------------------------------------------------
# Local File: Write rendered script to disk for upload
# ------------------------------------------------------------------------------
resource "local_file" "ad_join_rendered" {
  filename = "./scripts/ad_join.ps1"
  content  = local.ad_join_script
}

# ------------------------------------------------------------------------------
# Storage Blob: Upload rendered script to the scripts container
# ------------------------------------------------------------------------------
# metadata.force_update uses timestamp() to ensure Terraform detects a change
# and re-uploads the blob on each apply when desired.
# ------------------------------------------------------------------------------
resource "azurerm_storage_blob" "ad_join_script" {
  name                   = "ad-join.ps1"
  storage_account_name   = azurerm_storage_account.scripts_storage.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = local_file.ad_join_rendered.filename
  metadata = {
    force_update = "${timestamp()}"
  }
}

# ------------------------------------------------------------------------------
# SAS Token: Short-lived, read-only access to the uploaded script
# ------------------------------------------------------------------------------
# Generates a SAS token permitting object-level read access for blobs only.
# Start time is set to -24h to avoid failures due to clock skew.
# ------------------------------------------------------------------------------
data "azurerm_storage_account_sas" "script_sas" {
  connection_string = azurerm_storage_account.scripts_storage.primary_connection_string

  resource_types {
    service   = false
    container = false
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start  = formatdate("YYYY-MM-DD'T'HH:mm:ss'Z'", timeadd(timestamp(), "-24h"))
  expiry = formatdate("YYYY-MM-DD'T'HH:mm:ss'Z'", timeadd(timestamp(), "72h"))

  permissions {
    read    = true
    write   = false
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
    filter  = false
    tag     = false
  }
}