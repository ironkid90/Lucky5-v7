#!/usr/bin/env bash
set -euo pipefail

prompt_default() {
  local var_name="$1"
  local prompt_text="$2"
  local default_value="$3"
  local current_value="${!var_name:-}"

  if [[ -n "${current_value}" ]]; then
    printf -v "$var_name" '%s' "${current_value}"
    return
  fi

  if [[ -t 0 ]]; then
    local reply
    read -r -p "${prompt_text} [${default_value}]: " reply
    reply="${reply:-$default_value}"
    printf -v "$var_name" '%s' "${reply}"
  else
    printf -v "$var_name" '%s' "${default_value}"
  fi
}

require_cmd() {
  local cmd="$1"
  local help_text="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "$help_text" >&2
    exit 1
  fi
}

require_cmd az "Install Azure CLI first: https://learn.microsoft.com/cli/azure/install-azure-cli"

if ! az account show >/dev/null 2>&1; then
  echo "No active Azure login found. Run: az login" >&2
  exit 1
fi

CURRENT_SUBSCRIPTION="$(az account show --query id -o tsv 2>/dev/null || true)"
STAMP="$(date +%Y%m%d%H%M%S)"

AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-${CURRENT_SUBSCRIPTION:-}}"
RESOURCE_GROUP="${RESOURCE_GROUP:-}"
LOCATION="${LOCATION:-}"
ACR_NAME="${ACR_NAME:-}"
PLAN_NAME="${PLAN_NAME:-}"
APP_NAME="${APP_NAME:-}"
APP_SERVICE_SKU="${APP_SERVICE_SKU:-}"
IMAGE_NAME="${IMAGE_NAME:-lucky5}"
IMAGE_TAG="${IMAGE_TAG:-$STAMP}"
ALLOWED_ORIGINS="${ALLOWED_ORIGINS:-}"
ADMIN_USER="${LUCKY5_ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="${LUCKY5_ADMIN_PASSWORD:-}"
ADMIN_PHONE="${LUCKY5_ADMIN_PHONE:-+96100000000}"

prompt_default AZURE_SUBSCRIPTION_ID "Azure subscription id" "${CURRENT_SUBSCRIPTION:-your-subscription-id}"
prompt_default RESOURCE_GROUP "Azure resource group" "lucky5-rg"
prompt_default LOCATION "Azure region" "eastus"
prompt_default ACR_NAME "Azure Container Registry name (lowercase, globally unique)" "lucky5${STAMP}"
prompt_default PLAN_NAME "Azure App Service plan name" "lucky5-plan"
prompt_default APP_NAME "Azure Web App name (globally unique)" "lucky5-${STAMP}"
prompt_default APP_SERVICE_SKU "Azure App Service SKU" "B1"
prompt_default ADMIN_USER "Lucky5 admin username" "admin"
prompt_default ADMIN_PHONE "Lucky5 admin phone" "+96100000000"

if [[ -z "${ADMIN_PASSWORD}" ]]; then
  if [[ -t 0 ]]; then
    read -r -s -p "Lucky5 admin password [admin123-change-me]: " ADMIN_PASSWORD
    echo
    ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123-change-me}"
  else
    ADMIN_PASSWORD="admin123-change-me"
  fi
fi

APP_URL="https://${APP_NAME}.azurewebsites.net"

if [[ -z "${ALLOWED_ORIGINS}" ]]; then
  if [[ -t 0 ]]; then
    read -r -p "Allowed CORS origins [${APP_URL}]: " ALLOWED_ORIGINS
    ALLOWED_ORIGINS="${ALLOWED_ORIGINS:-$APP_URL}"
  else
    ALLOWED_ORIGINS="$APP_URL"
  fi
fi

echo
echo "Using subscription: ${AZURE_SUBSCRIPTION_ID}"
echo "Using resource group: ${RESOURCE_GROUP}"
echo "Using region: ${LOCATION}"
echo "Using registry: ${ACR_NAME}"
echo "Using plan: ${PLAN_NAME}"
echo "Using app: ${APP_NAME}"
echo "Using image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "Allowed origins: ${ALLOWED_ORIGINS}"
echo

az account set --subscription "${AZURE_SUBSCRIPTION_ID}"

echo "Creating resource group..."
az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" --output none

if az acr show --name "${ACR_NAME}" --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
  echo "Using existing Azure Container Registry..."
else
  echo "Creating Azure Container Registry..."
  az acr create \
    --name "${ACR_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --sku Basic \
    --admin-enabled true \
    --output none
fi

echo "Building and pushing Docker image to Azure Container Registry..."
az acr build \
  --registry "${ACR_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --image "${IMAGE_NAME}:${IMAGE_TAG}" \
  --file Dockerfile \
  .

ACR_LOGIN_SERVER="$(az acr show --name "${ACR_NAME}" --resource-group "${RESOURCE_GROUP}" --query loginServer -o tsv)"
ACR_USERNAME="$(az acr credential show --name "${ACR_NAME}" --resource-group "${RESOURCE_GROUP}" --query username -o tsv)"
ACR_PASSWORD="$(az acr credential show --name "${ACR_NAME}" --resource-group "${RESOURCE_GROUP}" --query 'passwords[0].value' -o tsv)"

if az appservice plan show --name "${PLAN_NAME}" --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
  echo "Using existing App Service plan..."
else
  echo "Creating App Service plan..."
  az appservice plan create \
    --name "${PLAN_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --sku "${APP_SERVICE_SKU}" \
    --is-linux \
    --output none
fi

if az webapp show --name "${APP_NAME}" --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
  echo "Using existing Web App..."
else
  echo "Creating Web App..."
  az webapp create \
    --resource-group "${RESOURCE_GROUP}" \
    --plan "${PLAN_NAME}" \
    --name "${APP_NAME}" \
    --container-image-name "${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}" \
    --https-only true \
    --output none
fi

echo "Configuring Web App container settings..."
az webapp config container set \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${APP_NAME}" \
  --container-image-name "${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}" \
  --container-registry-url "https://${ACR_LOGIN_SERVER}" \
  --container-registry-user "${ACR_USERNAME}" \
  --container-registry-password "${ACR_PASSWORD}" \
  --output none

echo "Configuring Web App runtime settings..."
az webapp config set \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${APP_NAME}" \
  --always-on true \
  --web-sockets-enabled true \
  --output none

echo "Setting Lucky5 application settings..."
az webapp config appsettings set \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${APP_NAME}" \
  --settings \
    "WEBSITES_PORT=8080" \
    "PORT=8080" \
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE=false" \
    "ASPNETCORE_ENVIRONMENT=Production" \
    "CORS__ALLOWED_ORIGINS=${ALLOWED_ORIGINS}" \
    "LUCKY5_ADMIN_USERNAME=${ADMIN_USER}" \
    "LUCKY5_ADMIN_PASSWORD=${ADMIN_PASSWORD}" \
    "LUCKY5_ADMIN_PHONE=${ADMIN_PHONE}" \
  --output none

echo
echo "Lucky5 deployed successfully to Azure App Service."
echo "Application URL: ${APP_URL}"
echo "Health URL: ${APP_URL}/health/live"
echo "SignalR Hub: ${APP_URL}/CarrePokerGameHub"
echo "Admin username: ${ADMIN_USER}"
echo "Next step: run 'az webapp log tail --resource-group ${RESOURCE_GROUP} --name ${APP_NAME}' if you want live startup logs."