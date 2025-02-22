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

# Define a resource group for all resources 
resource "azurerm_resource_group" "ad" {
  name     = "ad-resource-group" # Name of the resource group
  location = "Central US"           # Region where resources will be deployed
}
