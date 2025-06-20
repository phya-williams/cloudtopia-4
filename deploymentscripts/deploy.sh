#!/bin/bash

set -e  # Exit on error

REPO="https://github.com/phya-williams/cloudtopia-4"
FOLDER="cloudtopia-4"
ACR_NAME="cloudtopiaregistry"
DASHBOARD_IMAGE="html-dashboard:v2"
SIMULATOR_IMAGE="weather-simulator:v2"
CONTAINER_GROUP_NAME="weather-containers"
DASHBOARD_PORT=80
WORKSPACE_NAME="cloudtopia-logs"
ACTION_GROUP_NAME="CloudTopia-Weather-Alerts"

# Step 1: Clone or update repo
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

# Step 3: Clean up existing container group
echo "Cleaning up previous container group if it exists..."
az container delete --name $CONTAINER_GROUP_NAME --resource-group $RESOURCE_GROUP --yes || true

# Step 4: Clean up and re-create ACR
echo "Removing existing ACR (if any)..."
az acr delete --name $ACR_NAME --resource-group $RESOURCE_GROUP --yes || true

echo "Waiting for ACR to be fully deleted..."
sleep 10

echo "Creating fresh ACR: $ACR_NAME"
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic \
  --admin-enabled true

sleep 20  # Give it a moment to fully provision

export ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query "loginServer" -o tsv)
echo "Using ACR login server: $ACR_LOGIN_SERVER"

# Step 5: Get ACR credentials
export ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query "username" -o tsv)
export ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

# Step 6: Ensure dashboard container has required files
echo "Ensuring html-dashboard is prepared..."
if [ ! -f "html-dashboard/package.json" ]; then
  echo "Creating package.json for html-dashboard..."
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
touch html-dashboard/package-lock.json

# Step 7: Build and push containers with v2 tag
echo "Building and pushing dashboard container image..."
az acr build --registry $ACR_NAME --image "$DASHBOARD_IMAGE" html-dashboard/

echo "Building and pushing weather simulator container image..."
az acr build --registry $ACR_NAME --image "$SIMULATOR_IMAGE" weather-simulator/

echo "Waiting for image availability..."
sleep 10

echo "Confirming pushed tags:"
az acr repository show-tags --name $ACR_NAME --repository html-dashboard --output table
az acr repository show-tags --name $ACR_NAME --repository weather-simulator --output table

# Step 8: First deploy WITHOUT DASHBOARD_API_URL
echo "Deploying infrastructure WITHOUT dashboard URL..."
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file infrastructure/main.bicep \
  --parameters \
    acrUsername=$ACR_USERNAME \
    acrPassword=$ACR_PASSWORD \
    acrLoginServer=$ACR_LOGIN_SERVER

# Step 9: Wait for dashboard IP
echo "Waiting for dashboard public IP..."
sleep 15
PUBLIC_IP=$(az container show \
  --name $CONTAINER_GROUP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "ipAddress.ip" -o tsv)

if [[ -z "$PUBLIC_IP" ]]; then
  echo "Failed to get dashboard public IP"
  exit 1
fi

echo "Found dashboard IP: $PUBLIC_IP"

# Step 10: Re-deploy entire container group with DASHBOARD_API_URL injected
echo "Re-deploying container group with DASHBOARD_API_URL..."

DASHBOARD_URL="http://${PUBLIC_IP}/api/weather"

az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file infrastructure/main.bicep \
  --parameters \
    acrUsername=$ACR_USERNAME \
    acrPassword=$ACR_PASSWORD \
    acrLoginServer=$ACR_LOGIN_SERVER \
    dashboardApiUrl=$DASHBOARD_URL
