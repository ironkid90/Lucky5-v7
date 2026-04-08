# Lucky5-v7 — Agent Onboarding & Project State

_Last updated: 2026-04-08. This is the single authoritative catch-up document for any agent starting work on this repo._

---

## 1. What Is This Project

Lucky5 is a **clean-room recreation of a 1990–2010 Lebanese arcade video-poker machine** (no original code used). It runs as a self-contained web app:

- **Backend**: ASP.NET Core 9, single binary
- **Frontend**: Vanilla JS + CSS, served as static files from the same host
- **Realtime**: SignalR hub for machine-state sync (gameplay actions are REST, not SignalR)
- **Persistence**: All state is **in-memory** (no database yet — this is the biggest known limitation)
- **Deployment**: Single-instance Azure App Service via GitHub Actions CI/CD

The game identity is a retro portrait cabinet. The product goal is **faithful arcade parity**, not a generic casino UI. Never modernize the aesthetic.

---

## 2. Repository Map

```text
server/
  src/
    Lucky5.Api/           Web host, controllers, wwwroot/ (frontend)
    Lucky5.Application/   Service contracts + DTOs
    Lucky5.Domain/        Core engine (Game/CleanRoom/), entities
    Lucky5.Infrastructure/ Service implementations, in-memory store
    Lucky5.Realtime/      SignalR hub
    Lucky5.Simulation/    RTP simulation runner
  tests/
    Lucky5.Tests/         Integration + regression tests

server/src/Lucky5.Api/wwwroot/
  index.html              Single-page app shell (frozen DOM contract)
  js/game.js              Legacy game logic — primary frontend entry point
  js/cabinet-*-vnext.js   vNext modular layer (stage, pace, shell, state, audio, transition, orchestrator)
  css/game.css            Legacy base styles (do not edit)
  css/cabinet-*-vnext.css vNext override layer
  css/cabinet-frame-azurefix.css  Azure viewport fix (new)
  assets/                 Card PNGs, button images, fonts

docs/                     All design/arch docs (authoritative)
sources/                  Decompiled APK reference — READ ONLY, never edit
plans/                    Execution plans (may be stale — verify before following)
contracts/                OpenAPI + SignalR schemas
```

**Key source-of-truth files to read before any work:**

| File | What it tells you |
|------|-------------------|
| `docs/AGENT_ONBOARDING.md` (this file) | Full project state |
| `docs/CONTINUATION_GUIDE.md` | Economy model, session rules, admin tools |
| `docs/GAME_FEEL_REFERENCE.md` | Cabinet aesthetic — **sacrosanct** |
| `server/src/Lucky5.Domain/Game/CleanRoom/CLAUDE.md` | Engine invariants |
| `server/src/Lucky5.Infrastructure/CLAUDE.md` | Infrastructure layer rules |
| `server/src/Lucky5.Api/wwwroot/js/cabinet-orchestrator-vnext.js` | How legacy + vNext integrate |
| `AGENTS.md` (repo root) | Agent operating contract |

---

## 3. How To Run

```bash
# Run the server (serves frontend + API on port 5000)
dotnet run --project server/src/Lucky5.Api/Lucky5.Api.csproj --launch-profile http

# Run tests (use this command exactly — NOT dotnet test)
dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj

# Build check
dotnet build server/Lucky5.sln -v minimal
```

Test credentials: username `tester`, password `password`, OTP `123456`

---

## 4. Architecture Overview

### Backend layers

```text
GameController  →  IGameService (Application contract)
                       ↓
                   GameService (Infrastructure)
                       ↓
              FiveCardDrawEngine  +  Lucky5DoubleUpEngine  (Domain/CleanRoom)
                       ↓
                   MachinePolicy  (RTP shaping)
                       ↓
                   InMemoryDataStore  (all state lives here)
```

### Frontend layers

```text
game.js (legacy — handles all gameplay actions, API calls, UI state)
    ↑ patched by
cabinet-orchestrator-vnext.js  (patches renderCards, renderDoubleUpCards;
                                 dispatches RENDER_DEAL / RENDER_DRAW / RENDER_DOUBLEUP)
    ↓ calls
CabinetStage   (cabinet-stage-vnext.js)   — card slot rendering, DU viewport
CabinetPace    (cabinet-pace-vnext.js)    — animation timing
CabinetShell   (cabinet-shell-vnext.js)   — shell transitions
CabinetState   (cabinet-state-vnext.js)   — shared state store
CabinetAudio   (cabinet-audio-vnext.js)   — sound
CabinetTransition (cabinet-transition-vnext.js) — sequencer/lock
```

**Rule**: Backend is authoritative for all balances, machine state, jackpots, and double-up outcomes. Frontend only renders what the server says.

---

## 5. Game Rules (Non-Negotiable)

- Lebanese paytable: Royal Flush, Straight Flush, 4-of-a-Kind, Full House, Flush, Straight, 3-of-a-Kind, Two Pair — **no One Pair payout**
- Two Pair is the minimum qualifying hand
- Ace auto-wins in double-up
- **Lucky 5 no-lose** activates **only** when 5♠ is reached via SWITCH (not by being dealt or drawn naturally)
- Lucky5 win multiplier: ×4 first hit, ×2 repeat
- Max switch count per round: 2 (configurable)
- Machine closes when collected credits reach **40,000,000** machine credits
- Deal cost = `currentBet`; Draw cost = `currentBet`; player must have `2 × currentBet` to start a hand
- Jackpot wins go to **machine credits** directly; only base paytable win enters double-up

### Economy

| Balance | Location | Scope |
|---------|----------|-------|
| Wallet balance | `MemberProfile.WalletBalance` | Lobby / wallet screen |
| Machine credits | `MachineSessionState.MachineCredits` | In-game credit display |

- Cash-in increments: 200,000 machine credits at a time
- Cash-in cap per session: 1,000,000
- Cash-out allowed when: session is closed OR machine credits ≥ 2× total cash-in

---

## 6. Key API Endpoints

All REST. SignalR is sync-only (not used for gameplay actions).

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/Auth/login` | Login + JWT token |
| GET | `/api/Game/machine/{id}/session` | Machine session + wallet snapshot |
| GET | `/api/Game/machine/{id}/active-round` | Resume in-flight round |
| POST | `/api/Game/machine/{id}/cash-in` | Transfer wallet → machine credits |
| POST | `/api/Game/machine/{id}/cash-out` | Transfer machine credits → wallet |
| POST | `/api/Game/cards/deal` | Start a new hand |
| POST | `/api/Game/cards/draw` | Draw (resolve hand) |
| POST | `/api/Game/doubleup/start` | Enter double-up |
| POST | `/api/Game/doubleup/guess` | BIG / SMALL guess |
| POST | `/api/Game/doubleup/switch` | Switch dealer card |
| POST | `/api/Game/doubleup/cashout` | Collect and exit double-up |
| POST | `/api/Game/doubleup/take-half` | Collect half, continue |
| GET/POST | `/api/Admin/*` | Admin tools (restricted) |
| GET | `/health/live` | Health check |
| WS | `/CarrePokerGameHub` | SignalR machine-state sync |

SignalR group: `machine-{id}`. Events: `MachineStateUpdated`, `JackpotUpdated`, `SessionUpdated`.

---

## 7. RTP & Policy System

**Target: 85% RTP** (validated simulation pass 2026-03-14)

Distribution:
- Base game: ~72.5% (scaled by `MachinePolicy`)
- Jackpots: ~3.5%
- Double-up: ~9.0%

### EngineConfig key values (current, in `CoreModels.cs`)

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `TargetRtp` | 0.85 | Overall target |
| `DefaultPayoutScale` | 2.00 | Equilibrium scale |
| `MinPayoutScale` | 1.25 | Floor (prevents cold extremes) |
| `MaxPayoutScale` | 2.35 | Ceiling (prevents overshoot) |
| `CorrectionGain` | 1.15 | Drift correction strength |
| `WarmupRounds` | 60 | New session generosity window |
| `StreakSoftThreshold` | 4 | Pity activates after N losses |
| `StreakHardThreshold` | 8 | Hard pity threshold |
| `CrisisThreshold` | 12 | Emergency boost threshold |

Do **not** modify these without running a simulation pass first (`Lucky5.Simulation`).

### MachinePolicy modes

- `Cold` → higher payout scale, more 5♠ pressure
- `Neutral` → default equilibrium
- `Hot` → suppressed scale, tighter deck

Policy runs per-round at deal time and uses smoothed drift, jackpot RTP, Lucky5 drought counter, and counterplay score.

---

## 8. Completed Work (Chronological)

### 2026-03-13 — Final QA Pass

- Fixed deal/draw affordability bug (now requires 2× bet up front)
- Fixed Lucky5 machine-close timing (close only on actual collection, not preview)
- Cleaned async `.Result` calls in GameService
- Added shared ledger lock (`InMemoryDataStore.LedgerSync`)
- Implemented jackpot-aware payout scaling

### 2026-03-14 — RTP Rebalancing (31 params)

- Tuned to 85% RTP target — validated: hits 85% ±0.5%
- 26.1% hit frequency, ~30% DU engagement
- Adjusted jackpot start values (FH: 90k, 4K: 140k, SF: 850k) — must match `game.js JACKPOT_RESET`

### 2026-03-15 — Jackpot UI Fixes

- Full House meter wired live (`#jp-counter-fh`)
- 4K active highlight uses `[data-jackpot-slot]` live nodes
- `getFourOfAKindSlotTag()` gates A/B slot tags to 4K hands only
- Regression tests added in `FrontendRegressionTests.cs`

### 2026-04-05 — Clone Parity vNext Layer

- New CSS files: `cabinet-layout-vnext.css`, `cabinet-labels-vnext.css`
- New JS modules: `cabinet-stage-vnext.js`, `cabinet-pace-vnext.js`, `cabinet-shell-vnext.js`, `cabinet-state-vnext.js`, `cabinet-audio-vnext.js`, `cabinet-transition-vnext.js`, `cabinet-orchestrator-vnext.js`
- Fixed double-animation bug (orchestrator skips legacy DOM rebuild when CabinetStage handles it)
- Fixed input guard (click capture, not pointerdown)
- Fixed canHold selector (data-index attribute)
- Fixed re-entrancy in `_applyButtonStatesFromSelectors`
- Fixed `planDepth` going negative (boolean lock flag)
- Fixed bare variable guards in orchestrator
- Added `RENDER_DRAW` dispatch for non-animated draw path
- Fixed `animateDrainToCredits` double-count
- Fixed `restoreRoundFromSnapshot` DU trail sync
- Added `CardTrail` + `IsLucky5Active` to `DoubleUpResultDto`
- Fixed CSS conflict: `cabinet-frame-vnext.css` stripped of zone pixel vars and transform:scale

### 2026-04-06/07 — Machine State Cache (Phase 3)

- New: `IMachineStateCache` interface (`Lucky5.Application/Contracts/`)
- New: `InMemoryMachineStateCache` with TTL (`Lucky5.Infrastructure/Services/`)
- New: `MachineCacheTtlOptions` (ActiveRound: 30s, MachineSession: 15s)
- `GameService` cache-aside reads on `GetActiveRoundAsync` + `GetMachineSessionAsync`
- Cache invalidated on: `CashIn`, `CashOut`, `Deal`, `Draw`, all 5 DU operations
- Registered in `ServiceCollectionExtensions` via `IOptions<MachineCacheTtlOptions>`

### 2026-04-07 — Phase 4: Server-Authoritative DU Challenger Card

- `cabinet-stage-vnext.js`: `enterDoubleUp` no longer calls `_startShuffle(4)` (random card animation removed)
- Challenger slot shows static card back until server responds with `challengerCard`
- `shuffleChallenger()` made a no-op (export kept for `cabinet-transition-vnext.js` compat)
- `cabinet-stage-vnext.js` bumped to `?v=2`

### 2026-04-08 — Azure Hardening (current session)

- `Program.cs`: `ForwardedHeaders` middleware added (trusts all proxies — correct for Azure App Service)
- `game.js` (v20):
  - `resolveApiBase()` — reads `window.LUCKY5_API_BASE_URL`, `<meta name="lucky5-api-base">`, or localStorage
  - `DEBUG_ENABLED` / `debugLog()` — gated by `?debug=1` or localStorage, zero prod noise
  - `apiCall()` hardened — parses as text first, throws readable error on non-JSON HTML responses
  - `updateViewportUnit()` — sets `--app-vh`, hooked to resize + orientationchange
  - `renderDealStage()` / `renderDrawStage()` — single render path (CabinetStage or legacy fallback)
  - Legacy post-draw animation loop removed (CabinetStage handles it)
  - `bindSingleButton()` — warns on duplicate IDs; DOMContentLoaded wired through it
  - `window.render_game_to_text` + `window.advanceTime` — devtools/Playwright diagnostic helpers
- `index.html`: `viewport-fit=cover`, `<meta name="lucky5-api-base" content="">`, `cabinet-frame-azurefix.css?v=1`
- New: `wwwroot/css/cabinet-frame-azurefix.css` — overrides `max-width: 540px` clamp, `--app-vh`-based sizing

---

## 9. What Is NOT Done Yet (Pending Work)

| Item | Priority | Notes |
|------|----------|-------|
| **Persistent storage** | High | Biggest architectural gap. Machine ledgers, sessions, and rounds are lost on restart. See `docs/LUCKY5_VNEXT_COMPLETION_PLAN.md` Track A. |
| Phase 5: EngineConfig softening | Medium | Deferred — needs simulation run first to identify exact deltas before touching validated RTP params |
| Phase 5: RTP simulation validation | Medium | Run `Lucky5.Simulation` against live service rules, then tune if needed |
| React cabinet parity | Low | `src/web/` is behind vanilla JS cabinet; deferred until vanilla cabinet is fully stable |
| Multi-region / scale-out | Blocked | Blocked by in-memory state |
| Audit log persistence | Medium | Admin actions not durably logged |

---

## 10. Deployment

### Active production path

GitHub Actions workflow: `.github/workflows/deploy-azure-app-service.yml`

Push to `main` → builds `Dockerfile` → pushes to ACR `lucky520260401001454` → deploys to Web App `lucky5-ik90-prod-20260401` in `westeurope`.

### Required Azure App Settings

| Key | Value |
|-----|-------|
| `WEBSITES_PORT` | `8080` |
| `PORT` | `8080` |
| `ASPNETCORE_ENVIRONMENT` | `Production` |
| `CORS__ALLOWED_ORIGINS` | `https://<app-name>.azurewebsites.net` |
| `WEBSITES_ENABLE_APP_SERVICE_STORAGE` | `false` |

Admin credentials are set in Azure portal — never committed to the repo.

### Post-deploy verification

1. `https://<app>.azurewebsites.net/health/live` → `{"status":"ok"}`
2. Open browser devtools, navigate to game, check `/api/Game/machine/{id}/session` → 200
3. In console run `render_game_to_text()` after machine open, first deal, first draw
4. Append `?debug=1` to URL to enable verbose API + SignalR logging in console

### Important constraints

- **Single instance only** — do not scale out until persistent storage is added
- A redeploy clears all in-memory state (machine ledgers, jackpots, active rounds)
- ARR affinity should stay ON (SignalR sticky session)
- WebSockets must be enabled in App Service configuration

---

## 11. Non-Negotiable Rules (Apply to All Agents)

1. **Never edit `sources/`** — decompiled reference only
2. **Never change Lebanese paytable, Ace auto-win, or Lucky5 switch mechanics**
3. **Backend is always authoritative** — frontend only renders server state
4. **Do not scale out or add multi-instance** until persistent storage exists
5. **Keep the retro cabinet feel** — no gradients on paytable text, no rounded corners, no generic SaaS styling
6. **Tests run with `dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj`**, not `dotnet test`
7. **Authoritative game logic lives in `server/src/Lucky5.Domain/Game/CleanRoom/`** and must stay deterministic
8. **Do not change RTP parameters** without running `Lucky5.Simulation` first

---

## 12. Quick-Reference: File Locations

| What you need | Where it is |
|---------------|-------------|
| Game rules / engine | `server/src/Lucky5.Domain/Game/CleanRoom/` |
| RTP policy | `server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs` |
| EngineConfig params | `server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs` (bottom of file) |
| All game state | `server/src/Lucky5.Infrastructure/Services/InMemoryDataStore.cs` |
| Game service (business logic) | `server/src/Lucky5.Infrastructure/Services/GameService.cs` |
| Machine cache | `server/src/Lucky5.Infrastructure/Services/InMemoryMachineStateCache.cs` |
| Cache interface | `server/src/Lucky5.Application/Contracts/IMachineStateCache.cs` |
| DI registration | `server/src/Lucky5.Infrastructure/Services/ServiceCollectionExtensions.cs` |
| API startup | `server/src/Lucky5.Api/Program.cs` |
| Frontend entry | `server/src/Lucky5.Api/wwwroot/js/game.js` |
| vNext orchestrator | `server/src/Lucky5.Api/wwwroot/js/cabinet-orchestrator-vnext.js` |
| vNext card stage | `server/src/Lucky5.Api/wwwroot/js/cabinet-stage-vnext.js` |
| Cabinet HTML | `server/src/Lucky5.Api/wwwroot/index.html` |
| Tests | `server/tests/Lucky5.Tests/` |
| CI/CD | `.github/workflows/deploy-azure-app-service.yml` |
| Azure guide | `AZURE_DEPLOYMENT_GUIDE.md` |
| Cabinet aesthetic ref | `docs/GAME_FEEL_REFERENCE.md` |
| APK forensics | `docs/forensics/` |
