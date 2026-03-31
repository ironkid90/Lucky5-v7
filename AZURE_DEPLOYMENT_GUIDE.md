# Azure Deployment Guide for Lucky5-v7

## Overview

Lucky5 should be deployed to Azure as a **single-region Azure App Service running the repo's root Dockerfile**, with **GitHub Actions building and deploying on pushes to `main`**.

This is the supported production path because:

- the backend is an ASP.NET Core 9 app
- the frontend is served from the same backend host
- SignalR/WebSockets need an always-running web app
- machine sessions, RTP memory, jackpots, and admin state are still stored in memory, so scale-out and multi-region are unsafe today
- GitHub-based CI/CD avoids uploading a local working tree for every deployment

## Supported deployment model

### One-time Azure bootstrap

Create or reuse these Azure resources in one region:

- one resource group
- one Azure Container Registry
- one Linux App Service plan
- one Linux Web App configured for a custom container

The Web App should use a system-assigned managed identity with `AcrPull` on the registry.

### Ongoing deployments

The repo's GitHub Actions workflow at `.github/workflows/deploy-azure-app-service.yml` is the active deployment path.

On every push to `main`, it:

1. logs into Azure using GitHub OIDC
2. builds the root `Dockerfile`
3. pushes the image to Azure Container Registry
4. ensures the App Service identity can pull from ACR
5. updates the Web App to the new image
6. checks `https://<app-name>.azurewebsites.net/health/live`

## Workflow configuration

The workflow currently targets one concrete production deployment:

- subscription: `343ce01c-0b2a-46a3-bb0e-24c0469a9bfe`
- resource group: `lucky5-rg`
- region: `westeurope`
- Azure Container Registry: `lucky520260401001454`
- Azure Web App: `lucky5-ik90-prod-20260401`

These values are committed directly in the workflow because they are infrastructure identifiers, not secrets. If you rename or recreate the Azure resources later, update the workflow file to match.

## Required Azure configuration

Before GitHub Actions can deploy, Azure must have:

- a Microsoft Entra application / service principal for GitHub Actions
- a federated credential for `repo:ironkid90/Lucky5-v7:ref:refs/heads/main`
- Azure RBAC allowing that principal to:
  - push images to ACR
  - update the Lucky5 Web App

## App settings the deployment preserves

The workflow ensures these runtime settings remain present:

- `WEBSITES_PORT=8080`
- `PORT=8080`
- `WEBSITES_ENABLE_APP_SERVICE_STORAGE=false`
- `ASPNETCORE_ENVIRONMENT=Production`
- `CORS__ALLOWED_ORIGINS=https://<app-name>.azurewebsites.net`

Admin credentials should be set directly on the Web App in Azure and should not be committed to GitHub.

## Manual trigger

You can also run the deployment manually from GitHub Actions with `workflow_dispatch`.

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

## Legacy note

The older local helper script `scripts/setup-azure.sh` reflects the previous local-machine-driven deployment flow. It is no longer the recommended production deployment path for Lucky5.

This guide was updated on 2026-04-01.
