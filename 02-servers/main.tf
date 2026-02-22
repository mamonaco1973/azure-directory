# ==============================================================================
# Terraform Entry Point (Consumer Module / Data-Driven)
# ------------------------------------------------------------------------------
# Purpose:
#   - Configures the AzureRM provider for this deployment.
#   - Loads metadata about the active subscription and caller identity.
#   - References existing infrastructure (Resource Group, Subnet, Key Vault).
#   - Defines required variables used across dependent modules/resources.
#
# Design:
#   - This file assumes core infrastructure (RG, VNet, Subnet, Vault) already
#     exists and is being referenced via data sources instead of created.
#   - Useful for layered deployments or post-bootstrap configuration modules.
# ==============================================================================

# ------------------------------------------------------------------------------
# Provider: AzureRM
# ------------------------------------------------------------------------------
# Enables provider feature flags affecting Key Vault destroy behavior.
# ------------------------------------------------------------------------------
provider "azurerm" {
  features {
    # --------------------------------------------------------------------------
    # Key Vault lifecycle behavior
    # --------------------------------------------------------------------------
    # purge_soft_delete_on_destroy:
    #   Immediately purges Key Vault on destroy (bypasses retention window).
    #
    # recover_soft_deleted_key_vaults:
    #   Prevents automatic recovery of previously soft-deleted vaults.
    # --------------------------------------------------------------------------
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = false
    }
  }
}

# ------------------------------------------------------------------------------
# Data Source: Active Subscription Metadata
# ------------------------------------------------------------------------------
# Retrieves subscription ID, display name, and tenant linkage.
# ------------------------------------------------------------------------------
data "azurerm_subscription" "primary" {}

# ------------------------------------------------------------------------------
# Data Source: Current Authenticated Client
# ------------------------------------------------------------------------------
# Returns tenant ID, object ID, and client ID for the identity running Terraform.
# ------------------------------------------------------------------------------
data "azurerm_client_config" "current" {}

# ------------------------------------------------------------------------------
# Variable: Resource Group Name
# ------------------------------------------------------------------------------
# Defines which existing Resource Group this module should target.
# ------------------------------------------------------------------------------
variable "resource_group_name" {
  description = "The name of the Azure resource group"
  type        = string
  default     = "ad-resource-group"
}

# ------------------------------------------------------------------------------
# Variable: Existing Key Vault Name
# ------------------------------------------------------------------------------
# Required input — must match an already-created Key Vault.
# ------------------------------------------------------------------------------
variable "vault_name" {
  description = "The name of the secrets vault"
  type        = string
  # default  = "ad-key-vault-qcxu2ksw"
}

# ------------------------------------------------------------------------------
# Data Source: Existing Resource Group
# ------------------------------------------------------------------------------
# Loads metadata (location, ID, tags, etc.) for reuse in this module.
# ------------------------------------------------------------------------------
data "azurerm_resource_group" "ad" {
  name = var.resource_group_name
}

# ------------------------------------------------------------------------------
# Data Source: Existing VM Subnet
# ------------------------------------------------------------------------------
# Used to attach network interfaces or reference subnet properties.
# ------------------------------------------------------------------------------
data "azurerm_subnet" "vm_subnet" {
  name                 = "vm-subnet"
  resource_group_name  = data.azurerm_resource_group.ad.name
  virtual_network_name = "ad-vnet"
}

# ------------------------------------------------------------------------------
# Data Source: Existing Key Vault
# ------------------------------------------------------------------------------
# Enables secret creation or retrieval without recreating the vault.
# ------------------------------------------------------------------------------
data "azurerm_key_vault" "ad_key_vault" {
  name                = var.vault_name
  resource_group_name = var.resource_group_name
}

# ------------------------------------------------------------------------------
# Variable: Default Azure AD Domain (Tenant Domain)
# ------------------------------------------------------------------------------
# Used for constructing UPN values (e.g., admin@tenant.onmicrosoft.com).
# Typically supplied via tfvars or automation.
# ------------------------------------------------------------------------------
variable "azure_domain" {
  description = "The default Azure AD domain"
  # default  = "mamonaco1973gmail.onmicrosoft.com"
}