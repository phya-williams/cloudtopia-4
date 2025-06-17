#!/bin/bash

set -e  # Exit on error

REPO="https://github.com/phya-williams/cloudtopia-4"
FOLDER="cloudtopia-4"
ACR_NAME="cloudtopiaregistry"
DASHBOARD_CONTAINER_NAME="dashboard"
CONTAINER_GROUP_NAME="weather-containers"
DASHBOARD_PORT=80
WORKSPACE_NAME="cloudtopia-logs"
ACTION_GROUP_NAME="CloudTopia-Weather-Alerts"


# Step 1: Clone repo if not already cloned
if [ ! -d "$FOLDER" ]; then
  git clone $REPO
  cd $FOLDER
else
  cd $FOLDER
  echo "Repo already cloned. Pulling latest updates..."
  git pull origin main
fi

# Step 2: Get sandbox resource group
export RESOURCE_GROUP=$(az group list --query "[0].name" -o tsv)
echo "Using resource group: $RESOURCE_GROUP"

# Step 3: Delete existing container group if it exists
echo "Cleaning up any previous container group..."
az container delete --name $CONTAINER_GROUP_NAME --resource-group $RESOURCE_GROUP --yes || true

# Step 4: Create ACR
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic \
  --admin-enabled true

echo "⏳ Waiting for ACR to be fully provisioned..."
sleep 20

az acr show --name $ACR_NAME --query "loginServer" -o tsv

# Step 5: Get ACR credentials
export ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query "username" -o tsv)
export ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

echo "📦 Ensuring dashboard container has necessary files..."

# Rebuild package.json if missing (for express + Azure Blob SDK)
if [ ! -f "html-dashboard/package.json" ]; then
  echo "📝 Creating package.json for html-dashboard..."
  cat <<EOF > html-dashboard/package.json
{
  "name": "cloudtopia-dashboard",
  "version": "1.0.0",
  "main": "server.js",
  "type": "commonjs",
  "dependencies": {
    "express": "^4.18.2",
    "@azure/storage-blob": "^12.16.0"
  }
}
EOF
fi

# Optional: create lockfile if needed to avoid npm warnings
touch html-dashboard/package-lock.json


# Step 6: Build and push containers before deploying
az acr build --registry $ACR_NAME --image html-dashboard:v2 html-dashboard/
az acr build --registry $ACR_NAME --image weather-simulator:v2 weather-simulator/

# Step 7: Deploy Bicep with ACR credentials
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file infrastructure/main.bicep \
  --parameters acrUsername=$ACR_USERNAME acrPassword=$ACR_PASSWORD

# Step 8: Auto-open dashboard public IP
echo "Waiting for container group public IP..."
sleep 15

PUBLIC_IP=$(az container show --name $CONTAINER_GROUP_NAME --resource-group $RESOURCE_GROUP --query "ipAddress.ip" -o tsv)

if [[ -n "$PUBLIC_IP" ]]; then
  echo "✅ Deployment complete! Opening dashboard at: http://${PUBLIC_IP}:${DASHBOARD_PORT}"
  if command -v xdg-open &> /dev/null; then
    xdg-open "http://${PUBLIC_IP}:${DASHBOARD_PORT}"
  elif command -v open &> /dev/null; then
    open "http://${PUBLIC_IP}:${DASHBOARD_PORT}"
  else
    echo "🔗 Visit manually: http://${PUBLIC_IP}:${DASHBOARD_PORT}"
  fi
else
  echo "⚠️ Could not retrieve public IP of container group."
fi

echo "🔧 Ensuring action group exists..."
az monitor action-group create \
  --name $ACTION_GROUP_NAME \
  --resource-group $RESOURCE_GROUP \
  --short-name ctweather \
  --location eastus \
  --action email ctalerts phya.williams@peopleshores.com
