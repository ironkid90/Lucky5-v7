# Lucky5

A clean-room recreation of a Lebanese amusement video poker machine (1990–2010 era).

ASP.NET Core 9 backend · Vanilla JS/CSS web cabinet · Flutter mobile client · Firebase push notifications

Features authentic Lebanese arcade aesthetics, machine-credit vs wallet-credit economy, progressive jackpots, inline double-up Hi-Lo mechanic, switch-only Lucky 5 protection, admin telemetry, daily reward bonuses, agent-based user tracking, and deterministic policy logic targeting ~85% RTP while smoothing online variance.

## Quick Start

```bash
# .NET backend + web cabinet (port 8080)
dotnet run --project server/src/Lucky5.Api/Lucky5.Api.csproj

# Flutter mobile client
cd client && flutter run
```

The backend serves the web cabinet as static files from the same process.

## Deployment

- **Docker / Cloud Run**: `docker build -f Dockerfile -t lucky5 .` → deploy to Cloud Run. See `docs/CLOUD_RUN_DEPLOYMENT.md`.
- **Azure App Service**: see `docs/AZURE_DEPLOYMENT_GUIDE.md` and `azure.yaml`.

## Documentation

| Document | Purpose |
| --- | --- |
| **[docs/CONTINUATION_GUIDE.md](docs/CONTINUATION_GUIDE.md)** | Fast developer handoff — economy model, rules, architecture |
| **[docs/README.md](docs/README.md)** | Full game rules, paytable, API reference |
| `docs/GAME_FEEL_REFERENCE.md` | Visual / UX reference from original cabinet |
| `docs/forensics/` | APK reverse-engineering findings |
| `contracts/` | OpenAPI and SignalR schemas |

## Repository Structure

```text
server/src/
├── Lucky5.Api/            Web host, controllers, static frontend (wwwroot/)
│   └── wwwroot/js/        cabinet-*.js modules (shell, audio, bonus, firebase, etc.)
├── Lucky5.Application/    Service contracts, DTOs, request/response models
├── Lucky5.Domain/         Core engine (Game/CleanRoom/), entities
│   └── Game/CleanRoom/    MachinePolicy.cs — authoritative RTP / variance logic
├── Lucky5.Infrastructure/ Service implementations, in-memory store, Firebase
├── Lucky5.Realtime/       SignalR hub
└── Lucky5.Simulation/     RTP simulation runner

client/                    Flutter mobile client (Android / iOS / Web / Windows)
└── lib/core/              ApiService, FirebaseService, keep-alive

docs/                      Developer documentation
sources/                   Decompiled reference material (read-only)
```

## Feature Highlights (v7)

- **Dual wallet**: `Credit` (bonus/agent-funded) + `WalletBalance` (cash), credit consumed first on cash-in
- **Daily reward**: spin-based bonus award, lobby banner UI, idempotent daily gate
- **Agent system**: agent entities, credit pool, user assignment — full admin API
- **Firebase push**: FCM via Admin SDK (backend) + web service worker + Flutter client
- **Image caching**: browser Cache API layer for game assets
- **Audio SFX**: 15 named events (deal, draw, win, jackpot, bonus-claim, doubleUp, etc.)
- **Session hardening**: active-round hydration, safe back-to-lobby, idempotent cash-out

## Reference Material

| Location | Content |
| --- | --- |
| `docs/GAME_FEEL_REFERENCE.md` | Visual design reference from original cabinet |
| `docs/forensics/` | APK reverse-engineering findings |
| `Arcade Game RNG Simulation Model.md` | RNG / math reference |
| `contracts/` | OpenAPI and SignalR schemas |
