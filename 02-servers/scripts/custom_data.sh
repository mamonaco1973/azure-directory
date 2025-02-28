#!/bin/bash

# This script automates the process of updating the OS, installing required packages,
# joining an Active Directory (AD) domain, configuring system settings, and cleaning
# up permissions.

# ---------------------------------------------------------------------------------
# Section 1: Update the OS and Install Required Packages
# ---------------------------------------------------------------------------------

# Update the package list to ensure the latest versions of packages are available.
apt-get update -y

# Set the environment variable to prevent interactive prompts during installation.
export DEBIAN_FRONTEND=noninteractive

# Install necessary packages for AD integration, system management, and utilities.
# - realmd, sssd-tools: Tools for AD integration and authentication.
# - libnss-sss, libpam-sss: Libraries for integrating SSSD with the system.
# - adcli, samba-common-bin, samba-libs: Tools for AD and Samba integration.
# - oddjob, oddjob-mkhomedir: Automatically create home directories for AD users.
# - packagekit: Package management toolkit.
# - nano, vim: Text editors for configuration file editing.
apt-get install less unzip realmd sssd-tools libnss-sss \
    libpam-sss adcli samba-common-bin samba-libs oddjob \
    oddjob-mkhomedir packagekit nano vim curl apt-transport-https \
    lsb-release gnupg -y

# ---------------------------------------------------------------------------------
# Section 2: Install AZ CLI
# ---------------------------------------------------------------------------------

curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/keyrings/microsoft-azure-cli-archive-keyring.gpg > /dev/null
AZ_REPO=$(lsb_release -cs)
echo "deb [signed-by=/etc/apt/keyrings/microsoft-azure-cli-archive-keyring.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" \
    | tee /etc/apt/sources.list.d/azure-cli.list
apt-get update -y
apt-get install -y azure-cli

# ---------------------------------------------------------------------------------
# Section 2: Configure AD as the identity provider
# ---------------------------------------------------------------------------------

az login --identity --allow-no-subscriptions
secretsJson=$(az keyvault secret show --name admin-ad-credentials --vault-name ${vault_name} --query value -o tsv)
admin_password=$(echo "$secretsJson" | jq -r '.password')

systemctl stop sssd

# Write the new sssd.conf
cat <<EOF > "/etc/sssd/sssd.conf"
[sssd]
services = nss, pam
config_file_version = 2
domains = mcloud.mikecloud.com
debug_level = 9

[domain/mcloud.mikecloud.com]
debug_level = 9

id_provider = ldap
auth_provider = ldap
chpass_provider = ldap

# LDAP Connection (Azure AD DS LDAP)
ldap_uri = ldap://mcloud.mikecloud.com

# Base DN for searches
ldap_search_base = DC=mcloud,DC=mikecloud,DC=com

# Bind DN (the admin account for LDAP queries)
ldap_default_bind_dn = CN=mcloud-admin,OU=AADDC Users,DC=mcloud,DC=mikecloud,DC=com
ldap_default_authtok = $admin_password

# Search bases for users and groups (can be customized if needed)
ldap_user_search_base = DC=mcloud,DC=mikecloud,DC=com
ldap_group_search_base = DC=mcloud,DC=mikecloud,DC=com

# Attribute mapping to Unix fields
ldap_user_object_class = user
ldap_user_name = sAMAccountName
ldap_user_uid_number = uidNumber
ldap_user_gid_number = gidNumber
ldap_user_home_directory = unixHomeDirectory
ldap_user_shell = loginShell

# Explicit attribute mapping (groups)
ldap_group_object_class = group
ldap_group_name = sAMAccountName
ldap_group_gid_number = gidNumber
ldap_group_member = member

ldap_schema = rfc2307bis

# Use ID mapping (unless you store POSIX attributes in AD)
ldap_id_mapping = False

# Credential caching (helps with offline logins)
cache_credentials = True

# Performance tuning
enumerate = False

# TLS (Optional, but recommended for secure LDAP)
#ldap_tls_cacert = /etc/sssd/ca.pem   # Point this to the root CA used by your AD DS LDAP if needed
#ldap_tls_reqcert = allow              # Use "demand" for stricter security if cert is trusted

# Additional options to handle UID/GID if needed (especially if Azure AD DS doesn't have POSIX attributes)
fallback_homedir = /home/%u
default_shell = /bin/bash
EOF

chmod 600 /etc/sssd/sssd.conf
#systemctl stop sssd
#systemctl enable sssd
#systemctl start sssd

