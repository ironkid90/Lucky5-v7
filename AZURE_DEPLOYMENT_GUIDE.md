# Azure Deployment Guide for Lucky5-v7

## Overview

Lucky5 should currently be deployed to Azure as a **single-region Azure App Service running the repo's root Dockerfile**.

This is the supported Azure path because:

- the backend is an ASP.NET Core 9 app
- the frontend is served from the same backend host
- SignalR/WebSockets need an always-running web app
- machine sessions, RTP memory, jackpots, and admin state are still stored in memory, so scale-out and multi-region are unsafe today

The active deployment helper is `scripts/setup-azure.sh`.

## Prerequisites

Before deploying, make sure you have:

- an Azure subscription
- Azure CLI installed
- an active Azure login from `az login`
- access to this repo locally
- Bash available on your machine if you want to use the helper script directly

On Windows, the easiest option is usually **Git Bash**.

## Recommended deployment command

From the repository root, run:

```bash
bash scripts/setup-azure.sh
```

The script prompts for:

- Azure subscription id
- resource group
- Azure region
- Azure Container Registry name
- App Service plan name
- Web App name
- admin username / password / phone
- allowed CORS origins

## What the script does

The Azure script performs these steps:

1. creates or reuses the resource group
2. creates or reuses Azure Container Registry
3. builds the root Dockerfile with `az acr build`
4. creates or reuses a Linux App Service plan
5. creates or reuses the Azure Web App as a custom container
6. configures container registry credentials for the web app
7. enables Always On and WebSockets
8. sets the runtime app settings Lucky5 needs:
   - `WEBSITES_PORT=8080`
   - `PORT=8080`
   - `ASPNETCORE_ENVIRONMENT=Production`
   - `CORS__ALLOWED_ORIGINS=...`
   - `LUCKY5_ADMIN_USERNAME=...`
   - `LUCKY5_ADMIN_PASSWORD=...`
   - `LUCKY5_ADMIN_PHONE=...`

## Example non-interactive usage

If you prefer to pre-set everything yourself:

```bash
AZURE_SUBSCRIPTION_ID="your-subscription-id" \
RESOURCE_GROUP="lucky5-rg" \
LOCATION="eastus" \
ACR_NAME="youruniqueacrname" \
PLAN_NAME="lucky5-plan" \
APP_NAME="your-unique-webapp-name" \
APP_SERVICE_SKU="B1" \
LUCKY5_ADMIN_USERNAME="admin" \
LUCKY5_ADMIN_PASSWORD="change-me-now" \
LUCKY5_ADMIN_PHONE="+96100000000" \
ALLOWED_ORIGINS="https://your-unique-webapp-name.azurewebsites.net" \
bash scripts/setup-azure.sh
```

## Post-deployment checks

After deployment, verify:

- app root: `https://<your-app-name>.azurewebsites.net`
- health: `https://<your-app-name>.azurewebsites.net/health/live`
- SignalR hub: `https://<your-app-name>.azurewebsites.net/CarrePokerGameHub`

To follow logs live:

```bash
az webapp log tail --resource-group <resource-group> --name <your-app-name>
```

## Important production notes

- Keep the deployment at **one instance**. Do not scale out horizontally yet.
- A redeploy or app restart can still clear machine state because persistence is still in memory.
- Multi-region deployment is not supported yet. See `AZURE_MULTI_REGION_GUIDE.md`.
- If you add a custom domain later, update `CORS__ALLOWED_ORIGINS` to include it.

## Troubleshooting

### App starts but browser shows errors

Check that `CORS__ALLOWED_ORIGINS` matches the final site URL.

### Container does not become healthy

Confirm the app settings include:

- `WEBSITES_PORT=8080`
- `PORT=8080`

Lucky5 listens on Azure's assigned port and exposes its health endpoint at `/health/live`.

### WebSocket or SignalR issues

Confirm WebSockets are enabled on the web app and that you are testing against the same origin configured in CORS.

### Names are rejected during creation

Azure Web App names and Azure Container Registry names must be globally unique.

## Notes about legacy Azure files

The old Node/App Service examples and ARM placeholder under `azure/` are not the active deployment path for the current Lucky5 app.

This guide was updated on 2026-03-31.
