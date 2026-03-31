# AZURE_MULTI_REGION_GUIDE

## Current status

Lucky5 should **not** be deployed in active/active multi-region mode yet.

The current production architecture still keeps these concerns in memory inside the app process:

- machine sessions
- machine ledgers and RTP memory
- jackpots
- admin state
- user/session runtime state used by gameplay flows

If you run multiple regions at the same time today, those regions will drift apart and players can land on different copies of the game state.

## Supported Azure deployment today

Use the single-region deployment documented in `AZURE_DEPLOYMENT_GUIDE.md` and automated by:

```bash
bash scripts/setup-azure.sh
```

Keep the app on one instance in one region until the state model is externalized.

## What must exist before multi-region is safe

Before enabling multi-region, Lucky5 needs at least:

1. durable shared persistence for machine ledgers, jackpots, machine sessions, and auth/session state
2. a clear cross-region consistency strategy for gameplay writes
3. SignalR/session fan-out strategy across instances or a managed realtime backplane
4. traffic routing and failover that preserve session affinity expectations
5. explicit recovery rules for in-flight rounds during failover or redeploy

## Suggested future Azure shape

Once state is externalized, a safer multi-region Azure architecture would look like:

- one deployment per region
- shared durable data store for authoritative game state
- shared cache/backplane only where required
- Azure Front Door or Traffic Manager for geo-routing and failover
- health probes and operational playbooks for regional failover

## Practical recommendation

For now:

- deploy one region only
- keep one app instance only
- treat restarts and redeploys as state-reset events until persistence is added

When the backend moves off the in-memory store, this guide can be expanded into a real multi-region rollout document.