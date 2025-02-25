# Configure the AzureRM provider
provider "azurerm" {
  # Enables the default features of the provider
  features {
    key_vault {
        purge_soft_delete_on_destroy    = true
        recover_soft_deleted_key_vaults = false
      }
    }
}

# Data source to fetch details of the primary subscription
data "azurerm_subscription" "primary" {}

# Data source to fetch the details of the current Azure client
data "azurerm_client_config" "current" {}

# Define variables for resource group name and location

variable "resource_group_name" {
  description = "The name of the Azure resource group"
  type        = string
  default     = "ad-resource-group"
}

# VAULT_NAME=$(az keyvault list --resource-group ad-resource-group --query "[?starts_with(name, 'ad-key-vault')].name | [0]" --output tsv)

variable "vault_name" {
  description = "The name of the secrets vault"
  type        = string
#  default     = "ad-key-vault-qcxu2ksw"
}

data "azurerm_resource_group" "ad" {
  name = var.resource_group_name
}

data "azurerm_subnet" "vm_subnet" {
  name                 = "vm-subnet"
  resource_group_name  = data.azurerm_resource_group.ad.name
  virtual_network_name = "ad-vnet"
}


data "azurerm_key_vault" "ad_key_vault" {
  name                = var.vault_name
  resource_group_name = var.resource_group_name
}
