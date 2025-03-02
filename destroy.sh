
#!/bin/bash


if az ad group show --group "AAD DC Administrators" >/dev/null 2>&1; then
    echo "NOTE: Deleting AAD DC Administrators group to avoid conflicts..."
    az ad group delete --group "AAD DC Administrators"
fi

cd 02-servers

default_domain=$(az rest --method get --url "https://graph.microsoft.com/v1.0/domains" --query "value[?isDefault].id" --output tsv)
echo "NOTE: Default domain for account is $default_domain"
vault=$(az keyvault list --resource-group ad-resource-group --query "[?starts_with(name, 'ad-key-vault')].name | [0]" --output tsv)
echo "NOTE: Key vault for secrets is $vault"
terraform init
terraform destroy -var="vault_name=$vault" -var="azure_domain=$default_domain" -auto-approve

cd ..

cd 01-directory

terraform init
terraform destroy -var="azure_domain=$default_domain" -auto-approve

cd ..


