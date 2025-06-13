param location string = 'eastus'
param storageAccountName string = 'cloudtopiablob2025'
param containerName string = 'weatherdata'
param acrName string = 'cloudtopiaregistry'
param dashboardImage string = 'html-dashboard:v1'
param simulatorImage string = 'weather-simulator:v1'
param containerGroupName string = 'weather-containers'
param acrUsername string
param acrPassword securestring


resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: { name: 'Standard_LRS' }
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
          image: acr.name + '.azurecr.io/' + dashboardImage
          ports: [
            {
              port: 80
            }
          ]
          resources: {
            requests: {
              cpu: 0.5
              memoryInGb: 1
            }
          }
        }
      }
      {
        name: 'simulator'
        properties: {
          image: acr.name + '.azurecr.io/' + simulatorImage
          resources: {
            requests: {
              cpu: 0.5
              memoryInGb: 1
            }
          }
        }
      }
    ]
    imageRegistryCredentials: [
      {
        server: acr.name + '.azurecr.io'
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


resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(containerGroup.id, 'blob-contributor')
  scope: storageAccount
  properties: {
    principalId: containerGroup.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
  }
}
