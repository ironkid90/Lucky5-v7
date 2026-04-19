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

## Persistence on Cloud Run

Lucky5 keeps authoritative state in memory and checkpoints a full snapshot every 10 seconds via `PersistentStateCheckpointService`. On Cloud Run (stateless containers), pick one of the following backing stores so state survives revision rollouts, cold starts, and crashes.

### Option A — GCS FUSE volume (recommended, zero extra infra)

Cloud Run Gen 2 can mount a Cloud Storage bucket as a filesystem path. Lucky5 ships with a `FilePersistentStateStore` that reads and writes snapshots atomically at that path. No Redis, no SQL, no new NuGet packages.

```bash
BUCKET_NAME="${PROJECT_ID}-lucky5-state"

# 1. Create the bucket (any regional class works; single-region matches Cloud Run locality)
gcloud storage buckets create "gs://${BUCKET_NAME}" \
  --project "${PROJECT_ID}" \
  --location "${REGION}" \
  --uniform-bucket-level-access

# 2. Mount it into the service and point the app at it
gcloud run services update "${SERVICE_NAME}" \
  --region "${REGION}" \
  --execution-environment gen2 \
  --add-volume "name=lucky5-state,type=cloud-storage,bucket=${BUCKET_NAME}" \
  --add-volume-mount "volume=lucky5-state,mount-path=/mnt/lucky5-state" \
  --update-env-vars "LUCKY5_STATE_DIR=/mnt/lucky5-state"
```

The service account used by the Cloud Run revision needs `roles/storage.objectAdmin` on the bucket. For auto-managed revisions this is the compute default SA; grant it once:

```bash
PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
  --member "serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role roles/storage.objectAdmin
```

### Option B — Redis (Memorystore or Upstash)

If you already run Redis for other services, set the connection string and the existing `RedisPersistentStateStore` takes over automatically:

```bash
gcloud run services update "${SERVICE_NAME}" \
  --region "${REGION}" \
  --update-env-vars "CONNECTIONSTRINGS__REDIS=host:6379,password=..."
```

### Option C — Cloud SQL (PostgreSQL) — future work

`server/src/Lucky5.Infrastructure/Data/Lucky5DbContext.cs` and `EfCoreDataStore` are scaffolded for PostgreSQL (JSONB columns, concurrency tokens). Wiring them in requires refactoring `AuthService`, `AdminService`, and `GeneralService` to depend on `IDataStore` instead of `InMemoryDataStore`. Track this as the long-term migration when you need multi-instance horizontal scaling.

### Fallback (no env vars)

If neither `LUCKY5_STATE_DIR` nor a Redis connection string is set, the app still runs but state is in-process only. That is fine for local development and short-lived preview deployments.

## Important note about machine history

The machine ledger does **not** reset when a machine closes — "machine closed" is only a gameplay event. Without Option A or B configured, a full process restart or redeploy will clear history. With either option configured, the last checkpoint (up to 10 s old) is restored automatically on the next start by `PersistentStateRecoveryService`.

## Optional next improvements

- move machine ledgers and sessions into Cloud SQL or Firestore for durable long-term history (Option C above)
- add a custom domain on Cloud Run
- store admin credentials in Secret Manager instead of plain environment variables
