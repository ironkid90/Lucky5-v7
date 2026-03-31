# Azure Deployment Guide for Lucky5-v7

## Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Deployment Steps](#deployment-steps)
4. [Post-Deployment](#post-deployment)
5. [Troubleshooting](#troubleshooting)
6. [Additional Resources](#additional-resources)

## Introduction

This document serves as a comprehensive guide for deploying the Lucky5-v7 application on Azure. It outlines all necessary steps from setup to troubleshooting.

## Prerequisites

Before starting the deployment, ensure that you have the following:
- An Azure account with active subscription.
- Azure CLI installed on your machine.
- Access to the Lucky5-v7 codebase repository.

## Deployment Steps

1. **Clone the Repository**  
   Use the following command to clone the repository:  
   ```bash
   git clone https://github.com/ironkid90/Lucky5-v7.git
   cd Lucky5-v7
   ```

2. **Login to Azure**  
   Authenticate with your Azure account:  
   ```bash
   az login
   ```

3. **Create a Resource Group**  
   Organize your resources by creating a resource group:  
   ```bash
   az group create --name Lucky5ResourceGroup --location eastus
   ```

4. **Create an App Service Plan**  
   ```bash
   az appservice plan create --name Lucky5Plan --resource-group Lucky5ResourceGroup --sku B1 --is-linux
   ```

5. **Create a Web App**  
   Create a new web app using the command below:  
   ```bash
   az webapp create --resource-group Lucky5ResourceGroup --plan Lucky5Plan --name <your-app-name> --runtime "NODE|14-lts"
   ```

6. **Deploy the Application**  
   You can deploy your code using the following command:  
   ```bash
   az webapp deployment source config --name <your-app-name> --resource-group Lucky5ResourceGroup --repo-url https://github.com/ironkid90/Lucky5-v7.git -- branch main --manual-integration
   ```

## Post-Deployment

- **Access the Web App**  
   After deployment, the application can be accessed at:  
   `https://<your-app-name>.azurewebsites.net`

- **Monitoring and Logs**  
   Use Azure portal to monitor your application performance and review logs.

## Troubleshooting

- **Failed Deployment**  
   If the deployment fails, check the Azure logs for details. Use the command:  
   ```bash
   az webapp log tail --name <your-app-name> --resource-group Lucky5ResourceGroup
   ```

- **Common Errors**  
   - Ensure your runtime choices match within Azure environments.
   - Ensure the correct repository URL is used for deployment.

## Additional Resources

- [Azure App Service Documentation](https://docs.microsoft.com/en-us/azure/app-service/)  
- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)  
- [Lucky5-v7 Repository](https://github.com/ironkid90/Lucky5-v7)  

---

This guide was last updated on 2026-03-31.
  
