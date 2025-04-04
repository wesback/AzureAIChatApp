terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "<your-resource-group>"
  location = "<your-region>"
}

resource "azurerm_container_group" "chat_app" {
  name                = "azure-ai-chat-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_address_type     = "Public"
  dns_name_label      = "azure-ai-chat-app-unique"
  os_type             = "Linux"

  container {
    name   = "azure-ai-chat-app"
    image  = "<your-image-name>"
    cpu    = "1"
    memory = "1.5"

    ports {
      port     = 8501
      protocol = "TCP"
    }

    environment_variables = {
      AZURE_OPENAI_ENDPOINT = "<your-azure-endpoint>"
      AZURE_OPENAI_API_KEY  = "<your-api-key>"
    }
  }
}

resource "azurerm_container_registry" "acr" {
  name                = "mycontainerregistry"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Basic"
  admin_enabled       = true
}

output "fqdn" {
  value = azurerm_container_group.chat_app.fqdn
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}
