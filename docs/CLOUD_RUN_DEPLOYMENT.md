# Cloud Run Deployment

This is the recommended easiest deployment path for Lucky5.

## Why this is the easiest option

- frontend and backend stay in one ASP.NET Core app
- no separate static hosting step is required
- WebSockets / SignalR work on Cloud Run
- the deploy script pins the app to **min 1 / max 1** to preserve in-memory machine history and RTP memory as much as possible
- the script auto-enables the required Google APIs and auto-detects the final Cloud Run URL

## Before the first deploy

1. Install the Google Cloud SDK.
2. Run `gcloud auth login`.
3. Create or choose a Google Cloud project with billing enabled.
4. Pick a region (the script defaults to `me-west1`).

## One-command deploy

The script can now prompt for missing values interactively, so the shortest path is simply:

```bash
bash scripts/deploy-cloud-run.sh
```

If you prefer explicit environment variables, you can still run:

```bash
PROJECT_ID=your-project \
REGION=me-west1 \
SERVICE_NAME=lucky5 \
LUCKY5_ADMIN_USERNAME=admin \
LUCKY5_ADMIN_PASSWORD=change-me-now \
bash scripts/deploy-cloud-run.sh
```

If you want to allow an extra custom domain or a separate frontend origin later, add it as a comma-separated list:

```bash
PROJECT_ID=your-project \
ALLOWED_ORIGINS=https://your-custom-domain.com,https://your-run-url.run.app \
bash scripts/deploy-cloud-run.sh
```

## What the script does

- enables `run.googleapis.com`, `cloudbuild.googleapis.com`, and `artifactregistry.googleapis.com`
- deploys the repo directly to Cloud Run from the root `Dockerfile`
- sets the app to `min 1 / max 1` with session affinity
- reads the final service URL and uses it as the default allowed origin when you do not provide one
- prompts for project / region / service / admin credentials when you do not pre-set them in the shell

## Important note about machine history

The machine ledger does **not** reset when a machine closes. Machine closed is only a gameplay event. However, the repo still stores machine history in memory, so a full process restart or redeploy can still clear history. For truly month-scale durability, the next step is persistent storage for machine ledgers and machine sessions.

## Optional next improvements

- move machine ledgers and sessions into Cloud SQL or Firestore for durable history
- add a custom domain on Cloud Run
- store admin credentials in Secret Manager instead of plain environment variables
