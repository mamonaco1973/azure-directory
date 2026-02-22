# ==============================================================================
# Azure AD Domain Services (AADDS)
# ------------------------------------------------------------------------------
# Purpose:
#   - Deploys Azure AD Domain Services into a dedicated subnet.
#   - Applies a dedicated NSG to the AADDS subnet with required inbound rules.
#   - Updates the VNet DNS server list to point at the AADDS DC IP addresses.
#
# Notes:
#   - Provider registration and AADDS service principal creation are handled
#     outside Terraform to avoid destroy-time issues (see commented blocks).
#   - AADDS requires a dedicated subnet; do not place other workloads there.
#   - The VNet DNS update impacts name resolution for all subnets in the VNet.
# ==============================================================================

# ------------------------------------------------------------------------------
# Azure Provider / Identity Prereqs (managed outside Terraform)
# ------------------------------------------------------------------------------
# These two settings were moved to ./check_env.sh
# Letting terraform manage these settings causes problems when
# destroying the project

# resource "azurerm_resource_provider_registration" "aadds" {
#   name = "Microsoft.AAD"
# }

# Put this in the build script - az ad sp create --id "2565bd9d-da50-47d4-8b85-4c97f669dc36"
# resource "azuread_service_principal" "aadds" {
#   client_id = "2565bd9d-da50-47d4-8b85-4c97f669dc36"
# }

# ------------------------------------------------------------------------------
# Network Security Group for AADDS Subnet
# ------------------------------------------------------------------------------
# Applies inbound rules required for AADDS operations and administration.
#
# Key points:
#   - 443 from the AADDS service tag supports directory sync / management flows.
#   - 5986 from the AADDS service tag supports secure management operations.
#   - 636 is LDAPS (if enabled / used by clients).
#   - 3389 is for RDP access from the "CorpNetSaw" service tag (admin access).
# ------------------------------------------------------------------------------
resource "azurerm_network_security_group" "aadds" {
  name                = "aadds-nsg"
  location            = azurerm_resource_group.ad.location
  resource_group_name = azurerm_resource_group.ad.name

  # ---------------------------------------------------------------------------
  # Allow Azure AD DS to sync / communicate over HTTPS
  # ---------------------------------------------------------------------------
  security_rule {
    name                       = "AllowSyncWithAzureAD"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureActiveDirectoryDomainServices"
    destination_address_prefix = "*"
  }

  # ---------------------------------------------------------------------------
  # Allow RDP from Microsoft corporate admin jump hosts (service tag)
  # ---------------------------------------------------------------------------
  security_rule {
    name                       = "AllowRD"
    priority                   = 201
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "CorpNetSaw"
    destination_address_prefix = "*"
  }

  # ---------------------------------------------------------------------------
  # Allow PowerShell Remoting over HTTPS (WinRM) from the AADDS service tag
  # ---------------------------------------------------------------------------
  security_rule {
    name                       = "AllowPSRemoting"
    priority                   = 301
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5986"
    source_address_prefix      = "AzureActiveDirectoryDomainServices"
    destination_address_prefix = "*"
  }

  # ---------------------------------------------------------------------------
  # Allow LDAPS to the managed domain controllers (client-to-AADDS)
  # ---------------------------------------------------------------------------
  security_rule {
    name                       = "AllowLDAPS"
    priority                   = 401
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "636"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ------------------------------------------------------------------------------
# Associate AADDS NSG to the AADDS Subnet
# ------------------------------------------------------------------------------
# Ensures the AADDS subnet enforces the rules above.
# ------------------------------------------------------------------------------
resource azurerm_subnet_network_security_group_association "aadds" {
  subnet_id                 = azurerm_subnet.aadds_subnet.id
  network_security_group_id = azurerm_network_security_group.aadds.id
}

# ------------------------------------------------------------------------------
# Azure AD Domain Services Instance
# ------------------------------------------------------------------------------
# Provisions the managed domain and deploys the initial replica set into the
# dedicated subnet.
#
# Configuration:
#   - domain_name is the managed domain clients will join/use for auth.
#   - FullySynced indicates password hashes are synced to AADDS.
#   - Notifications go to global and DC admins, plus your additional recipient.
#   - Security enables syncing of common auth password types.
# ------------------------------------------------------------------------------
resource "azurerm_active_directory_domain_service" "aadds" {
  name                = "mikecloud"
  location            = azurerm_resource_group.ad.location
  resource_group_name = azurerm_resource_group.ad.name

  domain_name               = "mcloud.mikecloud.com"
  sku                       = "Standard"
  domain_configuration_type = "FullySynced"

  # ---------------------------------------------------------------------------
  # Initial DC replica set placement
  # ---------------------------------------------------------------------------
  initial_replica_set {
    subnet_id = azurerm_subnet.aadds_subnet.id
  }

  # ---------------------------------------------------------------------------
  # Operational notifications
  # ---------------------------------------------------------------------------
  notifications {
    additional_recipients = ["mcloud-admin@${var.azure_domain}"]
    notify_dc_admins      = true
    notify_global_admins  = true
  }

  # ---------------------------------------------------------------------------
  # Password sync configuration (enables managed domain auth methods)
  # ---------------------------------------------------------------------------
  security {
    sync_kerberos_passwords = true
    sync_ntlm_passwords     = true
    sync_on_prem_passwords  = true
  }

  # ---------------------------------------------------------------------------
  # Ensure subnet NSG associations exist before deploying AADDS
  # ---------------------------------------------------------------------------
  depends_on = [
    azurerm_subnet_network_security_group_association.aadds,
    azurerm_subnet_network_security_group_association.vm-nsg-assoc
  ]
}

# ------------------------------------------------------------------------------
# Update VNet DNS Servers to Use AADDS Domain Controller IPs
# ------------------------------------------------------------------------------
# After AADDS is deployed, the managed DCs expose IP addresses. This updates
# the VNet DNS server list so VMs in the VNet resolve the managed domain.
# ------------------------------------------------------------------------------
# Update the DNS servers for the existing VNet
resource "azurerm_virtual_network_dns_servers" "aadds_dns_servers" {
  virtual_network_id = azurerm_virtual_network.ad_vnet.id
  dns_servers        = azurerm_active_directory_domain_service.aadds.initial_replica_set[0].domain_controller_ip_addresses
}