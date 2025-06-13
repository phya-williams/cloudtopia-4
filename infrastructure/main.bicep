param location string = 'eastus'
param storageAccountName string = 'cloudtopiablob2025'
param containerName string = 'weatherdata'
param acrName string = 'cloudtopiaregistry'
param dashboardContainerName string = 'cloudtopia-dashboard'
param simulatorContainerName string = 'weather-simulator'
param containerGroupName string = 'weather-containers'
param acrSku string = 'Basic'

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
  sku: { name: acrSku }
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
        name: dashboardContainerName
        properties: {
          image: '${acr.name}.azurecr.io/${dashboardContainerName}:v1'
          ports: [{ port: 80 }]
          resources: {
            requests: {
              cpu: 0.5
              memoryInGb: 1
            }
          }
        }
      }
      {
        name: simulatorContainerName
        properties: {
          image: '${acr.name}.azurecr.io/${simulatorContainerName}:v1'
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
        server: '${acr.name}.azurecr.io'
        username: acr.listCredentials().username
        password: acr.listCredentials().passwords[0].value
      }
    ]
    ipAddress: {
      type: 'Public'
      ports: [{ protocol: 'tcp'; port: 80 }]
    }
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerGroup.id, 'blob-data-contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: containerGroup.identity.principalId
  }
}
