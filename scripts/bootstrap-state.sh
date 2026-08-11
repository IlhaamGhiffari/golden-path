#!/usr/bin/env bash
set -euo pipefail

# One-time bootstrap: creates the Azure storage account that holds Terraform remote state.
# Idempotent — safe to re-run. Run from repo root: scripts/bootstrap-state.sh
# Requires: az logged in, subscription set (az account set).

RG="golden-path-state-rg"
ACCT="gpstateilhaam"
# NOTE: Azure for Students restricts deployable regions — must be one of:
# centralindia, eastasia, malaysiawest, southeastasia, koreacentral
LOCATION="${1:-southeastasia}"

az group create --name "$RG" --location "$LOCATION" --output none

az storage account create \
  --name "$ACCT" \
  --resource-group "$RG" \
  --sku Standard_LRS \
  --allow-blob-public-access false \
  --output none

az storage container create \
  --name tfstate \
  --account-name "$ACCT" \
  --auth-mode login \
  --output none

echo "State RG:   $RG"
echo "Storage:    $ACCT (Standard_LRS, no public access)"
echo "Container:  tfstate"
echo "Remote state will be stored as: tfstate/golden-path.tfstate"
