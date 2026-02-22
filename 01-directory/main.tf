# ==============================================================================
# Terraform Entry Point / Provider Configuration
# ------------------------------------------------------------------------------
# Purpose:
#   - Configures the AzureRM provider and provider feature flags used by this
#     project (Key Vault + Resource Group behavior).
#   - Loads identity/subscription context via data sources.
#   - Defines baseline variables (resource group name/location, tenant domain).
#   - Creates the primary resource group used by the deployment.
#
# Notes:
#   - Key Vault soft-delete/purge settings materially affect destroy behavior.
#   - The azure_domain variable is intended to be discovered via CLI (Graph)
#     and passed in via tfvars or environment-specific automation.
# ==============================================================================

# ------------------------------------------------------------------------------
# Provider: AzureRM
# ------------------------------------------------------------------------------
# Configures provider feature flags that influence delete/recovery behavior.
# ------------------------------------------------------------------------------
provider "azurerm" {
  # Enables the default features of the provider
  features {
    # --------------------------------------------------------------------------
    # Key Vault: control soft-delete purge/recovery behavior during destroy
    # --------------------------------------------------------------------------
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = false
    }

    # --------------------------------------------------------------------------
    # Resource Group: allow RG deletion even if it still contains resources
    # --------------------------------------------------------------------------
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# ------------------------------------------------------------------------------
# Data Sources: Subscription + Caller Identity
# ------------------------------------------------------------------------------
# Used for tenant/subscription context, ID lookups, and access decisions.
# ------------------------------------------------------------------------------
data "azurerm_subscription" "primary" {}

data "azurerm_client_config" "current" {}

# ------------------------------------------------------------------------------
# Variables: Resource Group Name + Location
# ------------------------------------------------------------------------------
# Defines the default deployment scope for all resources in this project.
# ------------------------------------------------------------------------------
variable "resource_group_name" {
  description = "The name of the Azure resource group"
  type        = string
  default     = "ad-resource-group"
}

variable "resource_group_location" {
  description = "The Azure region where the resource group will be created"
  type        = string
  default     = "Central US"
}

# ------------------------------------------------------------------------------
# Resource Group: Primary Deployment Container
# ------------------------------------------------------------------------------
# All project resources are created inside this resource group.
# ------------------------------------------------------------------------------
resource "azurerm_resource_group" "ad" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

# ------------------------------------------------------------------------------
# Variable: Default Azure AD Domain (Tenant Domain)
# ------------------------------------------------------------------------------
# Intended to be populated by automation using Microsoft Graph, e.g.:
#   PRIMARY_DOMAIN=$(az rest --method get \
#     --url "https://graph.microsoft.com/v1.0/domains" \
#     --query "value[?isDefault].id" \
#     --output tsv)
# ------------------------------------------------------------------------------
variable "azure_domain" {
  description = "The default Azure AD domain"
  # default  = "mamonaco1973gmail.onmicrosoft.com"
}