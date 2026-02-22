#!/bin/bash
# ==============================================================================
# validate.sh - Azure Directory Quick Start Validation (AADDS)
# ------------------------------------------------------------------------------
# Purpose:
#   - Queries Azure for expected Azure Directory Quick Start resources and prints
#     quick-start endpoints for copy/paste access.
#
# Scope:
#   - Looks up Public IP resources created by Terraform in 02-servers:
#       - Windows admin VM Public IP resource: windows-vm-ip
#       - Linux admin VM Public IP resource  : linux-vm-ip
#   - Discovers the Key Vault name created by Terraform in 01-directory:
#       - Key Vault name prefix: ad-key-vault-
#
# Fast-Fail Behavior:
#   - Script exits immediately on command failure, unset variables,
#     or failed pipelines.
#
# Requirements:
#   - Azure CLI installed and authenticated (az login).
#   - Resources deployed in the expected resource group.
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
RESOURCE_GROUP="${RESOURCE_GROUP:-ad-resource-group}"

WINDOWS_PUBLIC_IP_NAME="${WINDOWS_PUBLIC_IP_NAME:-windows-vm-ip}"
LINUX_PUBLIC_IP_NAME="${LINUX_PUBLIC_IP_NAME:-linux-vm-ip}"

KEYVAULT_PREFIX="${KEYVAULT_PREFIX:-ad-key-vault-}"

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
az_trim() {
  # Trims whitespace/newlines from az output.
  xargs 2>/dev/null || true
}

get_public_ip_fqdn() {
  local rg="$1"
  local name="$2"

  az network public-ip show \
    --resource-group "${rg}" \
    --name "${name}" \
    --query "dnsSettings.fqdn" \
    --output tsv 2>/dev/null | az_trim
}

get_public_ip_address() {
  local rg="$1"
  local name="$2"

  az network public-ip show \
    --resource-group "${rg}" \
    --name "${name}" \
    --query "ipAddress" \
    --output tsv 2>/dev/null | az_trim
}

get_key_vault_by_prefix() {
  local rg="$1"
  local prefix="$2"

  az keyvault list \
    --resource-group "${rg}" \
    --query "[?starts_with(name, '${prefix}')].name | [0]" \
    --output tsv 2>/dev/null | az_trim
}

fmt_host_line() {
  local label="$1"
  local fqdn="$2"
  local ip="$3"

  if [[ -n "${fqdn}" ]]; then
    printf "%-28s %s\n" "${label}" "${fqdn}"
  elif [[ -n "${ip}" ]]; then
    printf "%-28s %s\n" "${label}" "${ip}"
  else
    printf "%-28s %s\n" "${label}" "NOT FOUND"
  fi
}

# ------------------------------------------------------------------------------
# Lookups
# ------------------------------------------------------------------------------
windows_fqdn="$(get_public_ip_fqdn "${RESOURCE_GROUP}" "${WINDOWS_PUBLIC_IP_NAME}")"
windows_ip="$(get_public_ip_address "${RESOURCE_GROUP}" "${WINDOWS_PUBLIC_IP_NAME}")"

linux_fqdn="$(get_public_ip_fqdn "${RESOURCE_GROUP}" "${LINUX_PUBLIC_IP_NAME}")"
linux_ip="$(get_public_ip_address "${RESOURCE_GROUP}" "${LINUX_PUBLIC_IP_NAME}")"

vault_name="$(get_key_vault_by_prefix "${RESOURCE_GROUP}" "${KEYVAULT_PREFIX}")"

# ------------------------------------------------------------------------------
# Quick Start Output
# ------------------------------------------------------------------------------
echo ""
echo "============================================================================"
echo "Azure Directory Quick Start - Validation Output (Azure)"
echo "============================================================================"
echo ""

printf "%-28s %s\n" "NOTE: Resource Group:" "${RESOURCE_GROUP}"
printf "%-28s %s\n" "NOTE: Key Vault:"      "${vault_name:-NOT FOUND}"

echo ""
fmt_host_line "NOTE: Windows RDP Host:" "${windows_fqdn}" "${windows_ip}"
fmt_host_line "NOTE: Linux SSH Host:"   "${linux_fqdn}"   "${linux_ip}"

echo ""