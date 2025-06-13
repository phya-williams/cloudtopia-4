#!/bin/bash

set -e

RESOURCE_GROUP=$(az group list --query "[0].name" -o tsv)
WORKSPACE_NAME="cloudtopia-logs"
ACTION_GROUP_NAME="CloudTopia-Weather-Alerts"

echo "📡 Fetching Log Analytics Workspace ID..."
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$WORKSPACE_NAME" \
  --query id -o tsv)

echo "📡 Creating Alert Rules..."

# Alert 1: Rain Detection
az monitor alert create \
  --name "CloudTopia-Rain-Alert" \
  --resource-group "$RESOURCE_GROUP" \
  --description "Rain detected at CloudTopia - consider weather protocols" \
  --scopes "$WORKSPACE_ID" \
  --condition "Custom log search: StorageBlobLogs | where Uri contains 'weather-log' | where Uri contains 'Rain' or Uri contains 'rain' | where TimeGenerated > ago(5m) | summarize count() > 0" \
  --action-groups "$ACTION_GROUP_NAME" \
  --severity 2 \
  --evaluation-frequency "PT5M" \
  --window-size "PT5M"

# Alert 2: High Temperature
az monitor alert create \
  --name "CloudTopia-High-Temperature" \
  --resource-group "$RESOURCE_GROUP" \
  --description "High temperature detected - check guest comfort measures" \
  --scopes "$WORKSPACE_ID" \
  --condition "Custom log search: StorageBlobLogs | where Uri contains 'weather-log' | where OperationName == 'PutBlob' | where StatusCode == 201 | where TimeGenerated > ago(10m) | summarize count() > 0" \
  --action-groups "$ACTION_GROUP_NAME" \
  --severity 2 \
  --evaluation-frequency "PT10M" \
  --window-size "PT10M"

# Alert 3: Low Visibility
az monitor alert create \
  --name "CloudTopia-Low-Visibility" \
  --resource-group "$RESOURCE_GROUP" \
  --description "Low visibility conditions - safety protocols required" \
  --scopes "$WORKSPACE_ID" \
  --condition "Custom log search: StorageBlobLogs | where Uri contains 'weather-log' | where TimeGenerated > ago(10m) | where StatusCode == 201 | summarize UploadCount = count() | where UploadCount > 0" \
  --action-groups "$ACTION_GROUP_NAME" \
  --severity 1 \
  --evaluation-frequency "PT15M" \
  --window-size "PT15M"

# Alert 4: High Wind Speed
az monitor alert create \
  --name "CloudTopia-High-Wind" \
  --resource-group "$RESOURCE_GROUP" \
  --description "High wind detected - secure outdoor attractions" \
  --scopes "$WORKSPACE_ID" \
  --condition "Custom log search: StorageBlobLogs | where Uri contains 'weather-log' | where TimeGenerated > ago(15m) | where StatusCode == 201 | summarize RecentUploads = count() | where RecentUploads > 5" \
  --action-groups "$ACTION_GROUP_NAME" \
  --severity 1 \
  --evaluation-frequency "PT15M" \
  --window-size "PT15M"

# Alert 5: Storm Conditions
az monitor alert create \
  --name "CloudTopia-Storm-Conditions" \
  --resource-group "$RESOURCE_GROUP" \
  --description "Storm conditions detected - implement weather emergency protocols" \
  --scopes "$WORKSPACE_ID" \
  --condition "Custom log search: StorageBlobLogs | where Uri contains 'weather-log' | where Uri contains 'Rain' or Uri contains 'Cloudy' or Uri contains 'Overcast' | where TimeGenerated > ago(15m) | summarize StormIndicators = count() | where StormIndicators >= 2" \
  --action-groups "$ACTION_GROUP_NAME" \
  --severity 1 \
  --evaluation-frequency "PT10M" \
  --window-size "PT15M"

# Alert 6: Perfect Weather
az monitor alert create \
  --name "CloudTopia-Perfect-Weather" \
  --resource-group "$RESOURCE_GROUP" \
  --description "Perfect weather conditions - optimal park operations" \
  --scopes "$WORKSPACE_ID" \
  --condition "Custom log search: StorageBlobLogs | where Uri contains 'weather-log' | where Uri contains 'Sunny' or Uri contains 'Clear' | where TimeGenerated > ago(30m) | summarize PerfectConditions = count() | where PerfectConditions > 3" \
  --action-groups "$ACTION_GROUP_NAME" \
  --severity 4 \
  --evaluation-frequency "PT30M" \
  --window-size "PT30M"

echo "✅ All CloudTopia alerts created successfully!"
