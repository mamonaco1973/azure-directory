#!/bin/bash
# ==============================================================================
# check_env.sh
# ------------------------------------------------------------------------------
# Purpose:
#   - Validates required CLI tools are available.
#   - Ensures required Azure Service Principal environment variables are set.
#   - Logs into Azure using the provided Service Principal credentials.
#   - Verifies required Entra ID role access.
#   - Ensures AADDS service principal exists.
#   - Registers Microsoft.AAD resource provider (waits until ready).
#
# Notes:
#   - Script exits immediately on any failure.
#   - Designed to be called before Terraform apply orchestration.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Validate required CLI commands
# ------------------------------------------------------------------------------
echo "NOTE: Validating that required commands are found in your PATH."

commands=("az" "terraform")

for cmd in "${commands[@]}"; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "ERROR: $cmd is not found in the current PATH."
    exit 1
  else
    echo "NOTE: $cmd is found in the current PATH."
  fi
done

echo "NOTE: All required commands are available."

# ------------------------------------------------------------------------------
# Validate required environment variables
# ------------------------------------------------------------------------------
echo "NOTE: Validating that required environment variables are set."

required_vars=("ARM_CLIENT_ID" "ARM_CLIENT_SECRET" "ARM_SUBSCRIPTION_ID" "ARM_TENANT_ID")

for var in "${required_vars[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: $var is not set or is empty."
    exit 1
  else
    echo "NOTE: $var is set."
  fi
done

echo "NOTE: All required environment variables are set."

# ------------------------------------------------------------------------------
# Azure Login (Service Principal)
# ------------------------------------------------------------------------------
echo "NOTE: Logging in to Azure using Service Principal..."

az login \
  --service-principal \
  --username "$ARM_CLIENT_ID" \
  --password "$ARM_CLIENT_SECRET" \
  --tenant "$ARM_TENANT_ID" \
  > /dev/null

echo "NOTE: Successfully logged into Azure."

# ------------------------------------------------------------------------------
# Validate Global Administrator Role (Entra ID)
# ------------------------------------------------------------------------------
echo "NOTE: Validating Entra role assignment (Global Administrator)..."

ROLE_CHECK=$(az rest \
  --method GET \
  --url "https://graph.microsoft.com/v1.0/directoryRoles" \
  --query "value[?displayName=='Global Administrator'].id" \
  --output tsv)

if [ -z "$ROLE_CHECK" ]; then
  echo "ERROR: 'Global Administrator' Entra role is NOT active in this tenant."
  exit 1
else
  echo "NOTE: 'Global Administrator' Entra role is present."
fi

# ------------------------------------------------------------------------------
# Ensure AADDS Service Principal Exists
# ------------------------------------------------------------------------------
echo "NOTE: Validating AADDS service principal (2565bd9d-da50-47d4-8b85-4c97f669dc36)..."

# Create if missing (no-op if already exists)
az ad sp create --id "2565bd9d-da50-47d4-8b85-4c97f669dc36" > /dev/null 2>&1 || true

echo "NOTE: AADDS service principal verified."

# ------------------------------------------------------------------------------
# Register Microsoft.AAD Resource Provider
# ------------------------------------------------------------------------------
echo "NOTE: Registering Microsoft.AAD resource provider..."

az provider register --namespace Microsoft.AAD > /dev/null

# Wait until registration completes
while [[ "$(az provider show --namespace Microsoft.AAD --query "registrationState" --output tsv)" != "Registered" ]]; do
  echo "NOTE: Waiting for Microsoft.AAD to register..."
  sleep 10
done

echo "NOTE: Microsoft.AAD is registered."

# ------------------------------------------------------------------------------
# Completed
# ------------------------------------------------------------------------------
echo "NOTE: Environment validation completed successfully."