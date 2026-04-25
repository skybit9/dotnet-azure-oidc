#!/usr/bin/env bash
# -----------------------------------------------------------------------
# bootstrap.sh
# Run ONCE before first `terraform init` to create the Azure Storage
# backend that will hold Terraform state.
# Prerequisites: az cli logged in, correct subscription selected.
# -----------------------------------------------------------------------
set -euo pipefail

# ---- EDIT THESE --------------------------------------------------------
LOCATION="canadacentral"
TFSTATE_RG="tfstate-rg"
TFSTATE_SA="tfstateacct$(openssl rand -hex 4)"   # unique name
TFSTATE_CONTAINER="tfstate"
# -----------------------------------------------------------------------

echo "Creating resource group: $TFSTATE_RG"
az group create \
  --name "$TFSTATE_RG" \
  --location "$LOCATION"

echo "Creating storage account: $TFSTATE_SA"
az storage account create \
  --name "$TFSTATE_SA" \
  --resource-group "$TFSTATE_RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

echo "Creating blob container: $TFSTATE_CONTAINER"
az storage container create \
  --name "$TFSTATE_CONTAINER" \
  --account-name "$TFSTATE_SA"

echo ""
echo "================================================================"
echo "Bootstrap complete. Update infra/main.tf backend block with:"
echo "  storage_account_name = \"$TFSTATE_SA\""
echo "  resource_group_name  = \"$TFSTATE_RG\""
echo "  container_name       = \"$TFSTATE_CONTAINER\""
echo "================================================================"
