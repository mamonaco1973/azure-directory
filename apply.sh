#!/bin/bash

set -e

./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment check failed. Exiting."
  exit 1
fi

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

# Check if the group already exists
existing_group=$(az ad group show --group "AAD DC Administrators" --query "id" -o tsv 2>/dev/null || true)
#echo $existing_group

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

cd ..

cd 02-servers

vault=$(az keyvault list --resource-group ad-resource-group --query "[?starts_with(name, 'ad-key-vault')].name | [0]" --output tsv)
echo "NOTE: Key vault for secrets is $vault"
terraform init
terraform apply -var="vault_name=$vault" -var="azure_domain=$default_domain" -auto-approve

cd ..

