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

require_cmd gcloud "Install the Google Cloud SDK first: https://cloud.google.com/sdk/docs/install"

if ! gcloud auth list --filter=status:ACTIVE --format='value(account)' | grep -q .; then
  echo "No active gcloud login found. Run: gcloud auth login" >&2
  exit 1
fi

CURRENT_PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
PROJECT_ID="${PROJECT_ID:-${CURRENT_PROJECT:-}}"
REGION="${REGION:-}"
SERVICE_NAME="${SERVICE_NAME:-}"
ALLOWED_ORIGINS="${ALLOWED_ORIGINS:-}"
ADMIN_USER="${LUCKY5_ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="${LUCKY5_ADMIN_PASSWORD:-}"
ADMIN_PHONE="${LUCKY5_ADMIN_PHONE:-+96100000000}"

prompt_default PROJECT_ID "Google Cloud project id" "${CURRENT_PROJECT:-your-gcp-project}"
prompt_default REGION "Cloud Run region" "me-west1"
prompt_default SERVICE_NAME "Cloud Run service name" "lucky5"
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

echo
echo "Using project: ${PROJECT_ID}"
echo "Using region: ${REGION}"
echo "Using service: ${SERVICE_NAME}"
echo "Admin user: ${ADMIN_USER}"
echo "Admin phone: ${ADMIN_PHONE}"
echo

gcloud config set project "${PROJECT_ID}" >/dev/null

echo "Enabling required Google APIs..."
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com

echo "Deploying Lucky5 to Cloud Run..."
gcloud run deploy "${SERVICE_NAME}" \
  --source . \
  --region "${REGION}" \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --min 1 \
  --max 1 \
  --session-affinity \
  --timeout 3600 \
  --set-env-vars "LUCKY5_ADMIN_USERNAME=${ADMIN_USER},LUCKY5_ADMIN_PASSWORD=${ADMIN_PASSWORD},LUCKY5_ADMIN_PHONE=${ADMIN_PHONE}"

SERVICE_URL="$(gcloud run services describe "${SERVICE_NAME}" --region "${REGION}" --format='value(status.url)')"

if [[ -z "${ALLOWED_ORIGINS}" ]]; then
  if [[ -t 0 ]]; then
    read -r -p "Allowed CORS origins [${SERVICE_URL}]: " ALLOWED_ORIGINS
    ALLOWED_ORIGINS="${ALLOWED_ORIGINS:-$SERVICE_URL}"
  else
    ALLOWED_ORIGINS="${SERVICE_URL}"
  fi
fi

gcloud run services update "${SERVICE_NAME}" \
  --region "${REGION}" \
  --update-env-vars "CORS__ALLOWED_ORIGINS=${ALLOWED_ORIGINS}"

echo
echo "Lucky5 deployed successfully."
echo "Service URL: ${SERVICE_URL}"
echo "Allowed origins: ${ALLOWED_ORIGINS}"
echo "Admin username: ${ADMIN_USER}"
echo "Next step: open ${SERVICE_URL} in your browser."
