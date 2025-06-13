param location string = 'eastus'
param storageAccountName string = 'cloudtopiablob2025'
param containerName string = 'weatherdata'
param acrName string = 'cloudtopiaregistry'
param dashboardImage string = 'html-dashboard:v1'
param simulatorImage string = 'weather-simulator:v1'
param containerGroupName string = 'weather-containers'
param acrUsername string
@secure()
param acrPassword string

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  name: '${storageAccount.name}/default/${containerName}'
  properties: {
    publicAccess: 'None'
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

var acrLoginServer = acr.properties.loginServer

// Get the storage account connection string securely
var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value};EndpointSuffix=core.windows.net'

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerGroupName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    osType: 'Linux'
    containers: [
      {
        name: 'dashboard'
        properties: {
          image: '${acrLoginServer}/${dashboardImage}'
          ports: [
            {
              port: 80
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 1
            }
          }
        }
      }
      {
        name: 'simulator'
        properties: {
          image: '${acrLoginServer}/${simulatorImage}'
          environmentVariables: [
            {
              name: 'AZURE_STORAGE_CONNECTION_STRING'
              value: storageConnectionString
            }
            {
              name: 'AZURE_STORAGE_CONTAINER'
              value: containerName
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 1
            }
          }
        }
      }
    ]
    imageRegistryCredentials: [
      {
        server: acrLoginServer
        username: acrUsername
        password: acrPassword
      }
    ]
    ipAddress: {
      type: 'Public'
      ports: [
        {
          protocol: 'Tcp'
          port: 80
        }
      ]
    }
  }
}
