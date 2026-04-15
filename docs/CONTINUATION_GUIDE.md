# Continuation Guide

This document is the fastest way for another developer to catch up on the current Lucky5 codebase.

## Live frontend

The production frontend is the vanilla app served from:

- `server/src/Lucky5.Api/wwwroot/index.html`
- `server/src/Lucky5.Api/wwwroot/js/game.js`
- `server/src/Lucky5.Api/wwwroot/css/game.css`

Do **not** start from the prototype folders for feature work unless you are intentionally rebuilding the frontend.

## Core backend files

- `server/src/Lucky5.Api/Controllers/GameController.cs` — gameplay, machine session cash-in/out, jackpot rank, machine state
- `server/src/Lucky5.Api/Controllers/AuthController.cs` — signup/login/OTP/profile/history
- `server/src/Lucky5.Api/Controllers/AdminController.cs` — admin-only user/machine tools
- `server/src/Lucky5.Infrastructure/Services/GameService.cs` — authoritative game flow
- `server/src/Lucky5.Infrastructure/Services/AdminService.cs` — admin balance adjustments and machine inspection/reset
- `server/src/Lucky5.Infrastructure/Services/AuthService.cs` — auth and wallet profile operations
- `server/src/Lucky5.Infrastructure/Services/InMemoryDataStore.cs` — all in-memory state
- `server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs` — RTP / variance shaping / double-up deck pressure

## Economy model

There are now two balances:

1. **Lobby wallet balance**
   - shown in the lobby / wallet screens
   - stored on `MemberProfile.WalletBalance`
2. **Machine credit balance**
   - shown on the game CREDIT display
   - stored per player + machine in `MachineSessionState.MachineCredits`

### Machine session rules

- players cash in to the machine in **200,000** increments
- total cash-in per machine session is capped at **1,000,000**
- cash-out to wallet is allowed when either:
  - the machine session is marked closed, or
  - machine credits reach at least **2x** total cash-in

## Jackpot / double-up rules

- jackpot values can start at max
- jackpot wins reset to 20% baseline values
- jackpot values never grow above their max caps
- jackpot win value goes straight to **machine credits**
- only the **base paytable win** enters double-up
- the Lucky 5 no-lose state only arms when 5♠ is reached through **SWITCH**; opening dealer 5♠ and BIG/SMALL reveal 5♠ are visual only
- the paytable row for the active hand is reused as the live score row during win/double-up

## Machine closed

Machine closed is a gameplay event, not a hard reset.

- machine ledgers continue accumulating history
- machine session is flagged closed for the current player
- player is expected to cash out machine credits back to the wallet
- machine RTP memory should keep running across closes

## RTP / fun policy

`MachinePolicy.cs` now uses:

- target RTP
- jackpot RTP pressure (not just base paytable RTP)
- net since last close
- Lucky 5 drought
- loss streak pressure
- counterplay / counterintuitive-hold pressure

This is meant to soften very long online dry spells while still letting the machine breathe with ups/downs and close misses.

The latest tuning pass also tightened the negative correction when the observed RTP is already above target, so jackpot-heavy periods push the normal paytable scale down faster instead of compounding the overshoot.

## Strange player behavior handling

`GameService.DrawAsync()` compares actual holds against advised holds and updates `MachineSessionState.CounterplayScore`.

This is then fed back into:

- deal-time policy mode selection
- draw-time payout scale pressure

So if a player repeatedly destroys strong hands or plays in an obviously counterintuitive way, the machine can compensate and keep the experience from becoming dead or overly punishing.

## Admin tools

Current admin features:

- search/list users
- credit or debit wallet balances with reasons
- inspect machine RTP and jackpot state
- inspect per-player machine sessions on each machine
- reset machine state separately from wallet adjustments

## Adding a new lobby game

1. Add a new entry to `AVAILABLE_GAMES` in `wwwroot/js/game.js`
2. Add any new route/screen handling in `showLobby()` / `openGame()`
3. Add the new backend controller/service if the game needs its own logic
4. Keep the existing Lucky5 frontend isolated so variants do not break the live cabinet

## Session continuity + close/reset hardening

Recent reliability work tightened the live vanilla cabinet flow without changing gameplay math or cabinet identity.

### Active-round hydration

- `GET /api/Game/machine/{id}/session` remains the authoritative machine-credit/session snapshot
- `GET /api/Game/machine/{id}/active-round` is now the canonical frontend resume route
- `GET /api/Game/active-round/{id}` remains aliased for older callers
- `game.js` hydrates backend truth into three cabinet phases:
  - `Dealt` → waiting for draw / hold selection
  - `Drawn` → win shown, waiting for TAKE SCORE or DOUBLE UP
  - `DoubleUp` → active dealer-card resume with switches/no-lose state
- remembered machine selection with **no active round** now exits safely back to the lobby instead of trapping the player in an empty cabinet view

### Close / cash-out / reset semantics

- machine close remains a **player session gameplay state**, not a machine-ledger reset
- repeated machine cash-out after a drained close path is treated as idempotent and returns the current session snapshot instead of throwing
- player-side machine reset now:
  - blocks only when the player still has a recoverable round on that machine
  - auto-cashes-out eligible/closed machine credits back to the wallet
  - clears the player machine session instead of wiping machine RTP history
- admin machine reset now blocks only on recoverable rounds and no longer blocks merely because a closed machine session still holds credits

### Frontend shell helpers

- screen transitions now route through shared helpers instead of scattered `classList` toggles
- the in-game `BACK TO LOBBY` action now lives inside the existing menu panel
- machine-close copy is centralized so idle, take-score, and cash-out CTA text stay in sync

## New in v7 (April 2026)

### Dual-credit economy

`MemberProfile` now carries two balances:

- **`Credit`** — bonus credit (awarded by agents, daily reward spin). Consumed first on cash-in.
- **`WalletBalance`** — real-money wallet. Consumed only when `Credit` is exhausted.
- **`MinimumOut`** — minimum withdrawal threshold per profile.
- **`TotalWins`** — lifetime win accumulator tracked server-side.

All cash-in calls are credit-first, then wallet. See `AuthService.CashInAsync` and `GameService.CashIn`.

### Daily bonus / reward system

- `GET /api/Reward/status` — returns `{ isEligible, bonusRechargeCount, nextEligibleUtc }`
- `POST /api/Reward/claim` — awards a spin-derived bonus (50,000–100,000 credits), gates to once per day
- Lobby shows a gold banner when the player is eligible; auto-hides after claim
- `BonusRechargeCount` on `MemberProfile` tracks lifetime claims
- Implementation: `RewardController`, `IRewardService`, `RewardService`

### Agent system

Agents are distributors who fund player credit pools.

- `Agent` entity: Id, Name, Code, PhoneNumber, CreditPool
- `MemberProfile.AgentId` links a player to their agent
- Admin API (`/api/Agent`): list agents, create, load credit, assign user
- `IAgentService` / `AgentService` — in-memory store (upgrade to DB for production)

### Enriched user profile

`MemberProfileDto` now exposes: `fullName`, `email`, `phoneNumber`, `generatedId`, `agentId`, `credit`, `walletBalance`, `minOut`, `totalWins`, `bonusRechargeCount`.

### Firebase push notifications

- **Backend**: `FirebaseAdmin` NuGet package, `INotificationService` / `FirebaseNotificationService`
- Gracefully no-ops when `Firebase:CredentialPath` / `Firebase:CredentialJson` not configured
- `POST /api/Notification/register-device` — stores FCM device token per user
- `GET /api/config/firebase` — serves public web SDK config to frontend
- **Web cabinet**: `cabinet-firebase.js` initialises SDK after login, registers service worker (`firebase-messaging-sw.js`), shows in-app banners for foreground messages
- **Flutter client**: `FirebaseService` in `client/lib/core/` — FCM setup, background handler, `wakelock_plus` keep-alive

**To activate**: populate `appsettings.json → Firebase` section with values from Firebase Console (service account key path, web API key, messaging sender ID, app ID, VAPID key). Place `google-services.json` in `client/android/app/` for Flutter Android.

### Image caching layer

`wwwroot/js/cabinet-image-cache.js` — browser Cache API wrapper. `fetchCached(url)` returns from cache on repeat loads; `preload(urls[])` warms the cache; `clear()` purges on logout.

### Audio SFX

`cabinet-audio-vnext.js` expanded to 15 named events: `press`, `invalid`, `deal`, `draw`, `collect`, `lucky5`, `machineClose`, `win`, `bonusClaim`, `doubleUpWin`, `doubleUpLose`, `cashIn`, `cashOut`, `hold`, `jackpot`. Drop MP3 files into `wwwroot/assets/sounds/` — missing files fail silently.

### New controllers

| Controller | Route | Purpose |
| --- | --- | --- |
| `RewardController` | `/api/Reward` | Daily bonus status + claim |
| `AgentController` | `/api/Agent` | Agent CRUD + credit loading (admin) |
| `NotificationController` | `/api/Notification` | FCM device token registration |
| `ConfigController` | `/api/config` | Public Firebase web config endpoint |

## Known limitation / next important step

Machine ledgers and machine sessions still live in memory. They survive long-running single-instance deployments but **not** process restarts or redeploys.

Agent state (`AgentService`) is also in-memory. For production: migrate both to PostgreSQL/Redis.

`DealAsync()` requires enough machine credits for both deal and draw up front — deliberate to avoid dead-end rounds.

For true month-scale durability, the next engineering step is persistent storage for:

- `MachineLedgerState`
- `MachineSessionState`
- `Agent` entities and credit history
- optionally audit / history rows
