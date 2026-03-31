#!/bin/bash

set -e

# Variables
RESOURCE_GROUP_NAME_EAST="Lucky5-East"
RESOURCE_GROUP_NAME_WEST="Lucky5-West"
REGISTRY_NAME="lucky5registry"
DATABASE_NAME="lucky5db"
APP_SERVICE_NAME="Lucky5App"

# Create Resource Groups
az group create --name $RESOURCE_GROUP_NAME_EAST --location "East US"
az group create --name $RESOURCE_GROUP_NAME_WEST --location "West Europe"

# Create Azure Container Registry in East US
az acr create --resource-group $RESOURCE_GROUP_NAME_EAST --name $REGISTRY_NAME --sku Basic

# Create Azure SQL Database in East US
az sql server create --name "lucky5sqleasts" --resource-group $RESOURCE_GROUP_NAME_EAST --location "East US" --admin-user "sqladmin" --admin-password "YourStrongPassword1!"
az sql db create --resource-group $RESOURCE_GROUP_NAME_EAST --server "lucky5sqleasts" --name $DATABASE_NAME --service-objective S0

# Create App Service Plan in East US
az appservice plan create --name "Lucky5PlanEast" --resource-group $RESOURCE_GROUP_NAME_EAST --sku S1 --is-linux
az webapp create --resource-group $RESOURCE_GROUP_NAME_EAST --plan "Lucky5PlanEast" --name $APP_SERVICE_NAME --runtime "NODE|14-lts"

# Create Azure Container Registry in West Europe
az acr create --resource-group $RESOURCE_GROUP_NAME_WEST --name $REGISTRY_NAME --sku Basic

# Create Azure SQL Database in West Europe
az sql server create --name "lucky5sqlwest" --resource-group $RESOURCE_GROUP_NAME_WEST --location "West Europe" --admin-user "sqladmin" --admin-password "YourStrongPassword1!"
az sql db create --resource-group $RESOURCE_GROUP_NAME_WEST --server "lucky5sqlwest" --name $DATABASE_NAME --service-objective S0

# Create App Service Plan in West Europe
az appservice plan create --name "Lucky5PlanWest" --resource-group $RESOURCE_GROUP_NAME_WEST --sku S1 --is-linux
az webapp create --resource-group $RESOURCE_GROUP_NAME_WEST --plan "Lucky5PlanWest" --name "Lucky5AppWest" --runtime "NODE|14-lts"