param identifier string = uniqueString(resourceGroup().id)
param location string = 'westeurope'
@allowed([
  'swedencentral'
  'australiaeast'
  'canadaeast'
  'eastus2'
  'francecentral'
  'uksouth'
])
param oaiLocation string = 'swedencentral'

resource oai 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: 'oai-${identifier}'
  location: oaiLocation
  sku: {
    name: 'S0'
  }
  kind: 'OpenAI'
  properties: {}
}

resource embeddings 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = {
  parent: oai
  name: 'embeddings'
  sku: {
    name: 'Standard'
    capacity: 120
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-ada-002'
      version: '2'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
}

resource gpt3 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = {
  parent: oai
  name: 'gpt-35-turbo'
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-35-turbo'
      version: '1106'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
  dependsOn: [ embeddings ]
}

resource gpt4 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = {
  parent: oai
  name: 'gpt-4-turbo'
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4'
      version: '1106-Preview'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
  dependsOn: [ embeddings, gpt3 ]
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: 'cr${identifier}'
  location: location
  sku: {
    name: 'Standard'
  }
}

resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-${identifier}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: []
    publicNetworkAccess: 'Enabled'
    enableSoftDelete: true
  }
}

resource strg 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'st${identifier}'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource blob 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: strg
  name: 'default'
  properties: {
    cors: {
      corsRules: [
        {
          allowedOrigins: [
            'https://mlworkspace.azure.ai'
            'https://ml.azure.com'
            'https://*.ml.azure.com'
            'https://ai.azure.com'
            'https://*.ai.azure.com'
          ]
          allowedMethods: [
            'GET'
            'POST'
            'PUT'
            'OPTIONS'
            'HEAD'
            'PATCH'
            'DELETE'
          ]
          allowedHeaders: [ '*' ]
          exposedHeaders: [ '*' ]
          maxAgeInSeconds: 3600
        }
      ]
    }
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: strg
  name: 'default'
  properties: {
    protocolSettings: {
      smb: {}
    }
    cors: {
      corsRules: [
        {
          allowedOrigins: [
            'https://mlworkspace.azure.ai'
            'https://ml.azure.com'
            'https://*.ml.azure.com'
            'https://ai.azure.com'
            'https://*.ai.azure.com'
          ]
          allowedMethods: [
            'GET'
            'POST'
            'PUT'
            'OPTIONS'
            'HEAD'
            'PATCH'
            'DELETE'
          ]
          allowedHeaders: [ '*' ]
          exposedHeaders: [ '*' ]
          maxAgeInSeconds: 3600
        }
      ]
    }
  }
}
resource log 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${identifier}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    retentionInDays: 30
  }
}

resource appi 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${identifier}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: log.id
    IngestionMode: 'LogAnalytics'
  }
}

resource hub 'Microsoft.MachineLearningServices/workspaces@2023-10-01' = {
  name: 'mlw-aihub-${identifier}'
  location: location
  sku: {
    name: 'Basic'
  }
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'AI Hub'
    storageAccount: strg.id
    keyVault: vault.id
    applicationInsights: appi.id
    containerRegistry: acr.id
    hbiWorkspace: false
    managedNetwork: {
      isolationMode: 'Disabled'
    }
    v1LegacyMode: false
    publicNetworkAccess: 'Enabled'
  }
}
