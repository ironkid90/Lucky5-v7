#!/bin/bash

# Automated Azure deployment setup script

# Update package index
sudo apt-get update

# Install Azure CLI
sudo apt-get install -y azure-cli

# Log in to Azure
az login --service-principal -u <CLIENT_ID> -p <CLIENT_SECRET> --tenant <TENANT_ID>

# Set the default subscription
az account set --subscription <SUBSCRIPTION_ID>

# Create a resource group
az group create --name MyResourceGroup --location eastus

# Deploy resources (example: Web App)
az deployment group create --resource-group MyResourceGroup --template-file azuredeploy.json --parameters azuredeploy.parameters.json

# Output success message
echo "Azure deployment setup completed successfully!"