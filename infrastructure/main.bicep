param location string = 'eastus'
param storageAccountName string = 'cloudtopiablob2025'
param containerName string = 'weatherdata'
param vnetName string = 'cloudtopia-vnet'
param subnetName string = 'weather-subnet'
param vnetAddressPrefix string = '10.0.0.0/16'
param subnetAddressPrefix string = '10.0.0.0/24'
param workspaceName string = 'weatheranalytics'
param appInsightsName string = 'weatherappinsights'
param appServicePlanName string = 'cloudtopia-plan'
param webAppName string = 'cloudtopia-dashboard'



var nsgName = '${vnetName}-nsg'

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {}
}

// Blob Container
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  name: '${storageAccount.name}/default/${containerName}'
  properties: {
    publicAccess: 'None'
  }
}

// Network Security Group
resource nsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Virtual Network + Subnet with NSG
resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// Monitoring
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}
 
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource servicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'B1'     // ✅ Use Basic B1 (Linux compatible)
    tier: 'Basic'
  }
  kind: 'linux'     // ✅ Must be 'linux' for Linux App Services
  properties: {
    reserved: true  // ✅ Must be true for Linux App Service
  }
}


// Container to run the Dashboard
resource weatherSimulator 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  name: 'cloudtopia-weather-dashboard'
  location: location
  properties: {
    containers: [
      {
        name: 'simulator'
        properties: {
          image: '${acrLoginServer}/weather-simulator:latest'
          resources: {
            requests: {
              cpu: 1.0
              memoryInGb: 1.5
            }
          }
          environmentVariables: [
            {
              name: 'AZURE_STORAGE_CONNECTION_STRING'
              value: storageAccount.listKeys().keys[0].value
            }
          ]
        }
      }
    ]
    osType: 'Linux'
    imageRegistryCredentials: [
      {
        server: acrLoginServer
        username: acrUsername
        password: acrPassword
      }
    ]
    restartPolicy: 'Always'
  }
  dependsOn: [
    storageAccount
  ]
}

// Container to run the Python weather simulator
resource weatherSimulator 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  name: 'cloudtopia-weather-simulator'
  location: location
  properties: {
    containers: [
      {
        name: 'simulator'
        properties: {
          image: '${acrLoginServer}/weather-simulator:latest'
          resources: {
            requests: {
              cpu: 1.0
              memoryInGb: 1.5
            }
          }
          environmentVariables: [
            {
              name: 'AZURE_STORAGE_CONNECTION_STRING'
              value: storageAccount.listKeys().keys[0].value
            }
          ]
        }
      }
    ]
    osType: 'Linux'
    imageRegistryCredentials: [
      {
        server: acrLoginServer
        username: acrUsername
        password: acrPassword
      }
    ]
    restartPolicy: 'Always'
  }
  dependsOn: [
    storageAccount
  ]
}

// Optional: Add same for dashboard if not using Azure Web App
