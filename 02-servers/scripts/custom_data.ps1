# ------------------------------------------------------------
# Install Active Directory Components
# ------------------------------------------------------------

echo "NOTE: Processing custom_data" > C:\custom_data.log  

# Suppress progress bars to speed up execution
$ProgressPreference = 'SilentlyContinue'

# Install required Windows Features for Active Directory management
Install-WindowsFeature -Name GPMC,RSAT-AD-PowerShell,RSAT-AD-AdminCenter,RSAT-ADDS-Tools,RSAT-DNS-Server

# ------------------------------------------------------------
# Install AZ CLI
# ------------------------------------------------------------

Invoke-WebRequest -Uri https://azcliprod.blob.core.windows.net/msi/azure-cli-2.51.0.msi -OutFile .\AzureCLI.msi
Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
Remove-Item .\AzureCLI.msi

# ------------------------------------------------------------
# Join instance to active directory
# ------------------------------------------------------------

$secretJson = az keyvault secret show --name admin-ad-credentials --vault-name ${vault_name} --query value -o tsv
$secretObject = $secretJson | ConvertFrom-Json
$password = $secretObject.password | ConvertTo-SecureString -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $secretObject.username, $password

# Join the EC2 instance to the Active Directory domain
Add-Computer -DomainName "${domain_fqdn}" -Credential $cred 

