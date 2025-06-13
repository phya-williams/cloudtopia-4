git clone https://github.com/phya-williams/cloudtopia-4
cd cloudtopia-4

export RESOURCE_GROUP=$(az group list --query "[0].name" -o tsv)
az acr create --resource-group $RESOURCE_GROUP --name cloudtopiaregistry --sku Basic --admin-enabled true

az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file infrastructure/main.bicep

az acr build --registry cloudtopiaregistry --image html-dashboard:v1 html-dashboard/
az acr build --registry cloudtopiaregistry --image weather-simulator:v1 weather-simulator/
