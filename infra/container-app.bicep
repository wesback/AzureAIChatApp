@description('Name of the Container App')
param containerAppName string = 'azure-ai-chat-app'

@description('Name for the Container App Environment')
param containerAppEnvName string = 'azure-ai-chat-env'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Docker image to deploy')
param image string

@description('Azure OpenAI Endpoint')
param azureOpenAIEndpoint string

@description('Azure OpenAI API Key')
@secure()
param azureOpenAIAPIKey string

@description('Registry type: DockerHub or ACR')
param registryType string = 'DockerHub'

@description('Registry username (required for ACR)')
@secure()
param registryUsername string = ''

@description('Registry password (required for ACR)')
@secure()
param registryPassword string = ''

@description('ACR registry name (required for ACR, without .azurecr.io)')
param registryName string = ''

// Container Apps Environment
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppEnvName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

// Log Analytics workspace for container app logs
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${containerAppName}-logs'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Container App
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8501
        transport: 'http'
        allowInsecure: false // Force SSL/TLS
      }
      registries: registryType == 'ACR' ? [
        {
          server: '${registryName}.azurecr.io'
          username: registryUsername
          passwordSecretRef: 'registry-password'
        }
      ] : []
      secrets: concat([
        {
          name: 'openai-api-key'
          value: azureOpenAIAPIKey
        }
      ], registryType == 'ACR' ? [
        {
          name: 'registry-password'
          value: registryPassword
        }
      ] : [])
    }
    template: {
      containers: [
        {
          name: containerAppName
          image: image
          env: [
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              value: azureOpenAIEndpoint
            }
            {
              name: 'AZURE_OPENAI_API_KEY'
              secretRef: 'openai-api-key'
            }
          ]
          resources: {
            cpu: 1
            memory: '2Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

output fqdn string = containerApp.properties.configuration.ingress.fqdn
