#!/bin/bash
# ==============================================================================
# destroy.sh
# ------------------------------------------------------------------------------
# Purpose:
#   - Orchestrates teardown in reverse dependency order:
#       1) 02-servers: destroy VMs and dependent resources (needs vault + domain)
#       2) 01-directory: destroy directory resources (needs domain)
#   - Optionally deletes the "AAD DC Administrators" Entra ID group to avoid
#     conflicts on subsequent rebuilds.
#
# Notes:
#   - This script assumes Azure CLI is authenticated and has permission to:
#       * Read Microsoft Graph default domain
#       * List Key Vaults in the target resource group
#       * Destroy Azure resources via Terraform
#       * Delete Entra ID groups (optional final step)
#   - The resource group name used for Key Vault discovery is fixed:
#       ad-resource-group
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Discover tenant default domain (used by both stacks)
# ------------------------------------------------------------------------------
default_domain=$(az rest \
  --method get \
  --url "https://graph.microsoft.com/v1.0/domains" \
  --query "value[?isDefault].id" \
  --output tsv)

echo "NOTE: Default domain for account is $default_domain"

# ------------------------------------------------------------------------------
# Destroy: 02-servers (dependent resources first)
# ------------------------------------------------------------------------------
cd 02-servers

vault=$(az keyvault list \
  --resource-group ad-resource-group \
  --query "[?starts_with(name, 'ad-key-vault')].name | [0]" \
  --output tsv)

echo "NOTE: Key vault for secrets is $vault"

terraform init
terraform destroy \
  -var="vault_name=$vault" \
  -var="azure_domain=$default_domain" \
  -auto-approve

cd ..

# ------------------------------------------------------------------------------
# Destroy: 01-directory (directory layer second)
# ------------------------------------------------------------------------------
cd 01-directory

terraform init
terraform destroy \
  -var="azure_domain=$default_domain" \
  -auto-approve

cd ..

# ------------------------------------------------------------------------------
# Optional Cleanup: Remove AAD DC Administrators group
# ------------------------------------------------------------------------------
# This avoids "already exists" conflicts across tenants where the group is not
# pre-created. Safe to skip if you want to preserve tenant configuration.
# ------------------------------------------------------------------------------
if az ad group show --group "AAD DC Administrators" >/dev/null 2>&1; then
  echo "NOTE: Deleting AAD DC Administrators group to avoid conflicts..."
  az ad group delete --group "AAD DC Administrators"
  echo "NOTE: Group deleted."
else
  echo "NOTE: Group 'AAD DC Administrators' not found. Skipping delete."
fi