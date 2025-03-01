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
terraform apply -var="azure_domain=$default_domain" -auto-approve

if [ $? -ne 0 ]; then
  echo "ERROR: Terraform apply failed in 01-directory. Exiting."
  exit 1
fi

cd ..

#cd 02-servers

#vault=$(az keyvault list --resource-group ad-resource-group --query "[?starts_with(name, 'ad-key-vault')].name | [0]" --output tsv)
#echo "NOTE: Key vault for secrets is $vault"
#terraform init
#terraform destroy -var="vault_name=$vault" -auto-approve
#terraform apply -var="vault_name=$vault" -auto-approve

#cd ..

