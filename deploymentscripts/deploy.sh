#!/bin/bash

set -e  # Exit on error

REPO="https://github.com/phya-williams/cloudtopia-4"
FOLDER="cloudtopia-4"
ACR_NAME="cloudtopiaregistry"
DASHBOARD_CONTAINER_NAME="dashboard"
CONTAINER_GROUP_NAME="weather-containers"
DASHBOARD_PORT=80

# Step 1: Clone repo if not already cloned
if [ ! -d "$FOLDER" ]; then
  git clone $REPO
fi
cd $FOLDER

# Step 2: Get sandbox resource group
export RESOURCE_GROUP=$(az group list --query "[0].name" -o tsv)
echo "Using resource group: $RESOURCE_GROUP"

# Step 3: Delete existing container group if it exists
echo "Cleaning up any previous container group..."
az container delete --name $CONTAINER_GROUP_NAME --resource-group $RESOURCE_GROUP --yes --no-wait || true

# Step 4: Create ACR
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic \
  --admin-enabled true

# Step 5: Get ACR credentials
export ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query "username" -o tsv)
export ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

# Step 6: Deploy Bicep with ACR credentials
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file infrastructure/main.bicep \
  --parameters acrUsername=$ACR_USERNAME acrPassword=$ACR_PASSWORD

# Step 7: Build and push containers
az acr build --registry $ACR_NAME --image html-dashboard:v1 html-dashboard/
az acr build --registry $ACR_NAME --image weather-simulator:v1 weather-simulator/

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
