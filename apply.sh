#!/bin/bash
# ==============================================================================
# apply.sh
# ------------------------------------------------------------------------------
# Purpose:
#   - Orchestrates a two-stage Terraform deployment:
#       1) 01-directory: Azure AD / AADDS directory prerequisites
#       2) 02-servers:   VM + supporting resources that depend on the directory
#   - Ensures environment prerequisites are satisfied before continuing.
#   - Discovers the tenant default domain via Microsoft Graph and passes it to
#     Terraform as the azure_domain variable.
#   - Ensures the "AAD DC Administrators" group exists (creates if missing).
#   - Discovers the Key Vault name created in stage 1 and passes it to stage 2.
#
# Notes:
#   - Script uses `set -e` (exit immediately on unhandled errors), but still
#     includes explicit `$?` checks in several places.
#   - Requires Azure CLI login with permissions for:
#       * Microsoft Graph (domains)
#       * Azure AD group read/create
#       * Resource group + Key Vault list access
#   - Assumes a fixed resource group name for Key Vault discovery:
#       ad-resource-group
# ==============================================================================

set -e

# ------------------------------------------------------------------------------
# Step 0: Environment validation (credentials, tooling, permissions)
# ------------------------------------------------------------------------------
./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment check failed. Exiting."
  exit 1
fi

# ------------------------------------------------------------------------------
# Step 1: Directory layer (01-directory)
#   - Discover tenant default domain
#   - Initialize Terraform
#   - Apply directory resources using azure_domain
# ------------------------------------------------------------------------------
cd 01-directory

default_domain=$(az rest --method get --url "https://graph.microsoft.com/v1.0/domains" --query "value[?isDefault].id" --output tsv)
echo "NOTE: Default domain for account is $default_domain"

terraform init

#terraform plan -var="azure_domain=$default_domain"
terraform apply -var="azure_domain=$default_domain" -auto-approve

if [ $? -ne 0 ]; then
  echo "ERROR: Terraform apply failed in 01-directory. Exiting."
  exit 1
fi

# ------------------------------------------------------------------------------
# Step 1b: Ensure "AAD DC Administrators" group exists
#   - AADDS uses this group for delegated domain admin privileges.
#   - If the group is missing in the tenant, create it.
# ------------------------------------------------------------------------------
existing_group=$(az ad group show --group "AAD DC Administrators" --query "id" -o tsv 2>/dev/null || true)
echo $existing_group

if [[ -z "$existing_group" ]]; then
    echo "WARNING: Group 'AAD DC Administrators' does not exist. Creating it now..."
    az ad group create \
      --display-name "AAD DC Administrators" \
      --mail-nickname "aaddcadmins" > /dev/null
    if [[ $? -eq 0 ]]; then
        echo "NOTE: Group 'AAD DC Administrators' created successfully."
    else
        echo "ERROR: Failed to create group 'AAD DC Administrators'."
        exit 1
    fi
else
    echo "NOTE: Group 'AAD DC Administrators' already exists with ID: $existing_group"
fi

# ------------------------------------------------------------------------------
# Step 2: Server layer (02-servers)
#   - Discover Key Vault name created by stage 1
#   - Initialize Terraform
#   - Apply server resources using vault_name + azure_domain
# ------------------------------------------------------------------------------
cd ..

cd 02-servers

vault=$(az keyvault list --resource-group ad-resource-group --query "[?starts_with(name, 'ad-key-vault')].name | [0]" --output tsv)
echo "NOTE: Key vault for secrets is $vault"

terraform init
terraform apply -var="vault_name=$vault" -var="azure_domain=$default_domain" -auto-approve

# ------------------------------------------------------------------------------
# Done
# ------------------------------------------------------------------------------
cd ..