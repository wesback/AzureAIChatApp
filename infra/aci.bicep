@description('Name of the container group')
param containerGroupName string = 'azure-ai-chat-app'

@description('Docker image to deploy')
param image string

@description('Azure OpenAI Endpoint')
param azureOpenAIEndpoint string

@description('Azure OpenAI API Key')
@secure()
param azureOpenAIAPIKey string

@description('Name of the Azure Container Registry')
param acrName string = 'myContainerRegistry'

@description('SKU of the Azure Container Registry')
param acrSku string = 'Basic'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: resourceGroup().location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: true
  }
}

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerGroupName
  location: resourceGroup().location
  properties: {
    containers: [
      {
        name: containerGroupName
        properties: {
          image: image
          ports: [
            {
              port: 8501
              protocol: 'TCP'
            }
          ]
          environmentVariables: [
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              value: azureOpenAIEndpoint
            }
            {
              name: 'AZURE_OPENAI_API_KEY'
              value: azureOpenAIAPIKey
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 1.5
            }
          }
        }
      }
    ]
    osType: 'Linux'
    ipAddress: {
      type: 'Public'
      ports: [
        {
          port: 8501
          protocol: 'TCP'
        }
      ]
      dnsNameLabel: containerGroupName
    }
  }
}

output fqdn string = containerGroup.properties.ipAddress.fqdn
output acrLoginServer string = containerRegistry.properties.loginServer
