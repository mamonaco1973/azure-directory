
#!/bin/bash

cd 02-servers

vault=$(az keyvault list --resource-group ad-resource-group --query "[?starts_with(name, 'ad-key-vault')].name | [0]" --output tsv)
echo $vault
terraform init
terraform destroy -var="vault_name=$vault" -auto-approve

cd ..

cd 01-directory

default_domain=$(az rest --method get --url "https://graph.microsoft.com/v1.0/domains" --query "value[?isDefault].id" --output tsv)
echo $default_domain
terraform init
terraform destroy -var="azure_domain=$default_domain" -auto-approve

cd ..


