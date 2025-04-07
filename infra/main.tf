provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "<your-resource-group>"
  location = "<your-region>"
}

resource "azurerm_log_analytics_workspace" "logs" {
  name                = "${azurerm_resource_group.rg.name}-logs"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
}

resource "azurerm_container_app_environment" "env" {
  name                       = "azure-ai-chat-env"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
}

resource "azurerm_container_app" "chat_app" {
  name                         = "azure-ai-chat-app"
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.chat_env.id
  revision_mode                = "Single"

  ingress {
    external_enabled = true
    target_port      = 8501
    transport        = "http"
    allow_insecure   = false
  }

  template {
    container {
      name  = "azure-ai-chat-app"
      image = "<your-image-name>"
      cpu   = 1
      memory = "2Gi"

      env {
        name  = "AZURE_OPENAI_ENDPOINT"
        value = "<your-azure-endpoint>"
      }

      env {
        name  = "AZURE_OPENAI_API_KEY"
        value = "<your-api-key>"
      }
    }

    min_replicas = 1
    max_replicas = 1
  }

  ingress {
    external_enabled = true
    target_port      = 8501
    transport        = "http"
  }

  resource_group_name        = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.chat_env.id

  registry {
    server   = "<your-registry-server>" # e.g., Docker Hub or ACR login server
    username = "<registry-username>"     # optional, required for ACR
    password = "<registry-password>"      # required if using ACR
  }
}

resource "azurerm_container_app_environment" "chat_env" {
  name                       = "azure-ai-chat-env"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
}

output "fqdn" {
  value = azurerm_container_app.chat_app.ingress[0].fqdn
}
