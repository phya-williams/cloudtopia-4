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

# Step 5: Get ACR credentials
export ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query "username" -o tsv)
export ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

# Step 6: Build and push containers before deploying
az acr build --registry $ACR_NAME --image html-dashboard:v1 html-dashboard/
az acr build --registry $ACR_NAME --image weather-simulator:v1 weather-simulator/

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

echo "📡 Creating alert rules in Log Analytics..."

# Rain Detection Alert
az monitor scheduled-query create \
  --name "CloudTopia-Rain-Alert" \
  --resource-group $RESOURCE_GROUP \
  --location eastus \
  --scopes $(az monitor log-analytics workspace show --resource-group $RESOURCE_GROUP --workspace-name $WORKSPACE_NAME --query id -o tsv) \
  --description "Rain detected at CloudTopia - consider weather protocols" \
  --severity 2 \
  --enabled true \
  --condition "count of results > 0" \
  --condition-query "StorageBlobLogs | where Uri contains 'weather-log' | where Uri contains 'Rain' or Uri contains 'rain' | where TimeGenerated > ago(5m) | summarize count()" \
  --action-groups $ACTION_GROUP_NAME \
  --evaluation-frequency "PT5M" \
  --window-size "PT5M"

# High Temperature Alert
az monitor scheduled-query create \
  --name "CloudTopia-High-Temperature" \
  --resource-group $RESOURCE_GROUP \
  --location eastus \
  --scopes $(az monitor log-analytics workspace show --resource-group $RESOURCE_GROUP --workspace-name $WORKSPACE_NAME --query id -o tsv) \
  --description "High temperature detected - check guest comfort measures" \
  --severity 2 \
  --enabled true \
  --condition "count of results > 0" \
  --condition-query "StorageBlobLogs | where Uri contains 'weather-log' | where OperationName == 'PutBlob' | where StatusCode == 201 | where TimeGenerated > ago(10m) | summarize count() | where count_ > 0" \
  --action-groups $ACTION_GROUP_NAME \
  --evaluation-frequency "PT10M" \
  --window-size "PT10M"

# Low Visibility Alert
az monitor scheduled-query create \
  --name "CloudTopia-Low-Visibility" \
  --resource-group $RESOURCE_GROUP \
  --location eastus \
  --scopes $(az monitor log-analytics workspace show --resource-group $RESOURCE_GROUP --workspace-name $WORKSPACE_NAME --query id -o tsv) \
  --description "Low visibility conditions - safety protocols required" \
  --severity 1 \
  --enabled true \
  --condition "count of results > 0" \
  --condition-query "StorageBlobLogs | where Uri contains 'weather-log' | where TimeGenerated > ago(10m) | where StatusCode == 201 | summarize UploadCount = count() | where UploadCount > 0" \
  --action-groups $ACTION_GROUP_NAME \
  --evaluation-frequency "PT15M" \
  --window-size "PT15M"

# High Wind Speed Alert
az monitor scheduled-query create \
  --name "CloudTopia-High-Wind" \
  --resource-group $RESOURCE_GROUP \
  --location eastus \
  --scopes $(az monitor log-analytics workspace show --resource-group $RESOURCE_GROUP --workspace-name $WORKSPACE_NAME --query id -o tsv) \
  --description "High wind detected - secure outdoor attractions" \
  --severity 1 \
  --enabled true \
  --condition "count of results > 5" \
  --condition-query "StorageBlobLogs | where Uri contains 'weather-log' | where TimeGenerated > ago(15m) | where StatusCode == 201 | summarize RecentUploads = count() | where RecentUploads > 5" \
  --action-groups $ACTION_GROUP_NAME \
  --evaluation-frequency "PT15M" \
  --window-size "PT15M"

# Storm Conditions Alert
az monitor scheduled-query create \
  --name "CloudTopia-Storm-Conditions" \
  --resource-group $RESOURCE_GROUP \
  --location eastus \
  --scopes $(az monitor log-analytics workspace show --resource-group $RESOURCE_GROUP --workspace-name $WORKSPACE_NAME --query id -o tsv) \
  --description "Storm conditions detected - implement weather emergency protocols" \
  --severity 1 \
  --enabled true \
  --condition "count of results >= 2" \
  --condition-query "StorageBlobLogs | where Uri contains 'weather-log' | where Uri contains 'Rain' or Uri contains 'Cloudy' or Uri contains 'Overcast' | where TimeGenerated > ago(15m) | summarize StormIndicators = count() | where StormIndicators >= 2" \
  --action-groups $ACTION_GROUP_NAME \
  --evaluation-frequency "PT10M" \
  --window-size "PT15M"

# Perfect Weather Alert
az monitor scheduled-query create \
  --name "CloudTopia-Perfect-Weather" \
  --resource-group $RESOURCE_GROUP \
  --location eastus \
  --scopes $(az monitor log-analytics workspace show --resource-group $RESOURCE_GROUP --workspace-name $WORKSPACE_NAME --query id -o tsv) \
  --description "Perfect weather conditions - optimal park operations" \
  --severity 4 \
  --enabled true \
  --condition "count of results > 3" \
  --condition-query "StorageBlobLogs | where Uri contains 'weather-log' | where Uri contains 'Sunny' or Uri contains 'Clear' | where TimeGenerated > ago(30m) | summarize PerfectConditions = count() | where PerfectConditions > 3" \
  --action-groups $ACTION_GROUP_NAME \
  --evaluation-frequency "PT30M" \
  --window-size "PT30M"
