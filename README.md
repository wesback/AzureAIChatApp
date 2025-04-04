# Azure AI Foundry Chat Application

> **Disclaimer:** All files in this repository are generated by GitHub Copilot. This is just sample code with no guarantees.

This project provides a Streamlit-based chat interface integrated with Azure OpenAI services. It allows users to interact with various Azure AI models, upload context files (text, PDF, images), and receive AI-generated responses.

## Features

- Interactive chat interface powered by Streamlit.
- Integration with Azure OpenAI models (GPT-3.5 Turbo, GPT-4o, Deepseek-R1, O3 Mini).
- Supports uploading context files (text, PDF, images) for enhanced interactions.

## Prerequisites

- Docker installed locally ([Docker Desktop](https://www.docker.com/products/docker-desktop/)).
- Azure subscription with access to Azure OpenAI services.
- Azure CLI installed ([Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)).

## Initial Azure Setup

1. **Log in to Azure CLI**:

```bash
az login
```

2. **Create a resource group**:

```bash
az group create --name <your-resource-group> --location <your-location>
```

## Environment Variables

Ensure you have the following environment variables set:

- `AZURE_OPENAI_ENDPOINT`: Your Azure OpenAI endpoint URL.
- `AZURE_OPENAI_API_KEY`: Your Azure OpenAI API key.

## Building and Running Locally with Docker

1. **Build the Docker image**:

```bash
docker build -t azureaichatapp .
```

2. **Run the Docker container locally**:

```bash
docker run -p 8501:8501 -e AZURE_OPENAI_ENDPOINT="<your-endpoint>" -e AZURE_OPENAI_API_KEY="<your-api-key>" azureaichatapp
```

3. **Access the application**:

For local development, use `http://localhost:8501` (HTTPS is not configured for localhost).

## Container Registry Setup and Deployment

You can push the image to either Docker Hub or Azure Container Registry (ACR). Choose the option that best suits your needs.

### Option 1: Using Docker Hub

1. **Log in and push to DockerHub**:

```bash
docker login
docker tag azureaichatapp <your-dockerhub-username>/azureaichatapp:latest
docker push <your-dockerhub-username>/azureaichatapp:latest
```

### Option 2: Using Azure Container Registry (ACR)

1. **Create and set up ACR**:

```bash
az acr create --resource-group <your-resource-group> --name <your-acr-name> --sku Basic
az acr login --name <your-acr-name>
```

2. **Push to ACR**:

```bash
docker tag azureaichatapp <your-acr-name>.azurecr.io/azureaichatapp:latest
docker push <your-acr-name>.azurecr.io/azureaichatapp:latest
```

## Deploying to Azure Container Instances (ACI)

Deploy using the Bicep template (`infra/aci.bicep`):

```bash
az deployment group create \
  --resource-group <your-resource-group> \
  --template-file infra/aci.bicep \
  --parameters image="<your-image-path>" \
               azureOpenAIEndpoint="<your-endpoint>" \
               azureOpenAIAPIKey="<your-api-key>" \
               registryType="<DockerHub|ACR>" \
               registryName="<your-acr-name>"
```

Replace `<your-image-path>` with either:
- DockerHub: `<your-dockerhub-username>/azureaichatapp:latest`
- ACR: `<your-acr-name>.azurecr.io/azureaichatapp:latest`

Set `registryType` to:
- `DockerHub` for images hosted on Docker Hub.
- `ACR` for images hosted on Azure Container Registry.

If using ACR with private access, add registry credentials:

```bash
az deployment group create \
  --resource-group <your-resource-group> \
  --template-file infra/aci.bicep \
  --parameters image="<your-acr-name>.azurecr.io/azureaichatapp:latest" \
               azureOpenAIEndpoint="<your-endpoint>" \
               azureOpenAIAPIKey="<your-api-key>" \
               registryType="ACR" \
               registryName="<your-acr-name>" \
               registryUsername="<registry-username>" \
               registryPassword="<registry-password>"
```

You can get ACR credentials using:
```bash
az acr credential show --name <your-acr-name>
```

### Using Azure Application Gateway for SSL Termination

To enable secure communication over HTTPS, this solution integrates with Azure Application Gateway. The Application Gateway handles SSL termination and proxies traffic to the Azure Container Instance (ACI) running on port 8501.

#### Steps to Configure Azure Application Gateway

1. **Update Parameters**:
   - Add the following parameters to your deployment command:
     - `applicationGatewayName`: The name of the Azure Application Gateway resource.
     - `publicIpName`: The name of the public IP resource for the Application Gateway.

2. **Deploy with Application Gateway**:
   ```bash
   az deployment group create \
     --resource-group <your-resource-group> \
     --template-file infra/aci.bicep \
     --parameters image="<your-image-path>" \
                  azureOpenAIEndpoint="<your-endpoint>" \
                  azureOpenAIAPIKey="<your-api-key>" \
                  registryType="<DockerHub|ACR>" \
                  registryName="<your-acr-name>" \
                  applicationGatewayName="<your-app-gateway-name>" \
                  publicIpName="<your-public-ip-name>"
   ```

3. **Access the Application**:
   - Once deployed, access your application securely at the public IP or DNS name of the Application Gateway.

#### Notes
- The Application Gateway listens on port 443 and forwards traffic to the ACI on port 8501.
- SSL termination is handled by the Application Gateway using the provided SSL certificate.
- Ensure that the SSL certificate is in PFX format and base64-encoded, and provide the password as a parameter.

## GitHub Actions CI/CD

This repository includes GitHub Actions workflow for automated container builds and deployments. The workflow:
- Triggers only on pushes to the main branch
- Builds the Docker image
- Pushes to either Docker Hub or Azure Container Registry (or both if configured)

### Required GitHub Secrets

Set up the following secrets in your GitHub repository settings:

For Docker Hub:
- `DOCKER_USERNAME`: Your Docker Hub username
- `DOCKER_PASSWORD`: Your Docker Hub access token

For Azure Container Registry:
- `AZURE_REGISTRY_URL`: Your ACR login server (e.g., `myregistry.azurecr.io`)
- `AZURE_REGISTRY_USERNAME`: ACR username
- `AZURE_REGISTRY_PASSWORD`: ACR password

### Branch Protection

To ensure only authorized changes reach the main branch:
1. Go to Repository Settings > Branches
2. Add branch protection rule for `main`
3. Enable:
   - Require pull request reviews
   - Require status checks to pass
   - Restrict who can push to matching branches

## Original Prompts
> Create a Python web app using Streamlit that allows me to call an Azure AI Foundry Endpoint to chat with. I want the user to be able to select a model (listed in a parameter in the app to make sure the developer has a choice which models are allowed). Provide the ability to upload a text file, PDF or image for context in the chat. The endpoint and API key should be configurable using an environment variable but also provide an input option in the web app itself so it can be changed at runtime.

> Create a README file for Github using Markup. Please add documentation about the project, also add instructions on how to build the docker file and run it locally next to the instructions on how to run this to Azure Container Instances. Feel free to add this prompt to the readme too.

> Create a bicep and a terraform file to deploy the Azure Container Intances.

> Can you add a Github Action to the project to build the docker container and push it to either Docker Hub or and Azure Container Registry? I assume you will need some secrets in the Github Action to make that work. Can you add the necessary steps to make sure this Github Action is only triggered on the main branch and that only I can merge changes into the main branch to prevent abuse?