# Lucky5 vNext Completion Plan

_Last updated: 2026-04-01_

## Purpose

This document consolidates the current Lucky5 codebase shape, the relevant documentation findings, and a practical vNext roadmap focused on:

1. durable persistence
2. better player/admin menu flows
3. supporting utilities and operational hardening
4. moving Lucky5 from a strong prototype into a more deployment-ready product

---

## Executive Summary

Lucky5 already has the core ingredients of a serious product:

- authoritative backend gameplay
- deterministic clean-room engine
- Lebanese cabinet-accurate vanilla frontend
- admin tooling
- machine-session economy
- RTP / jackpot / double-up policy systems
- Android wrapper path
- deployable single-service hosting model

But the repo is still bottlenecked by one major architectural limitation:

> **authoritative runtime state is still in memory**

That limitation cascades into nearly every remaining completion gap:

- machine history is lost on restart/redeploy
- single-instance hosting is mandatory
- multi-region is unsafe
- in-flight round recovery is weak
- admin operations lack durable audit depth
- long-session continuity is fragile

At the same time, the live frontend is feature-rich but navigation is still managed by duplicated DOM toggles and an overlay menu pattern that makes some core actions feel hidden or brittle.

**vNext should therefore be organized around three primary tracks:**

- **Track A — Persistence & recovery**
- **Track B — Navigation/menu/admin UX hardening**
- **Track C — Supporting utilities, observability, and delivery readiness**

---

## Recommended Next Batch — Session Continuity and Cabinet Flow Hardening

This is the highest-value implementation batch to run next without changing Lucky5's game rules, RTP philosophy, or cabinet identity.

### Why this batch first

The latest repo observations point to one practical truth:

- full durable persistence is still the biggest long-term architecture need
- but the most immediate player-facing reliability pain is concentrated in machine-close, cash-out, reset, reconnect, and navigation flows

That makes the next best batch a **tight vertical slice** that hardens the existing vanilla cabinet and backend flow before the larger persistence migration.

### Guardrails for this batch

Do **not** change any of the following:

- Lebanese paytable semantics
- Two Pair minimum qualifying hand
- Ace-always-wins double-up behavior
- Lucky 5 switch-only no-lose behavior and multipliers
- deterministic pre-shuffled outcome logic
- retro cabinet visual philosophy

### Batch goals

1. eliminate invalid or ambiguous machine-close / cash-out / reset paths around the 40,000,000 close threshold
2. restore continuous game state for long play sessions, refreshes, and reconnects using the existing active-round API surface
3. make all lobby, wallet, admin, and in-game menu actions follow one predictable navigation model
4. verify every critical cabinet button and recovery path with regression coverage

### Included work

#### Batch 1A. Machine-close, cash-out, and reset semantic hardening

Focus:

- audit all flows that cross `IsMachineClosed`, `CashOutAsync()`, double-up cashout, and admin reset
- ensure the 40M+ machine-close path always resolves into one of the allowed outcomes:
  - forced collect into machine credits
  - wallet cash-out
  - admin reset when no active round exists
- remove ambiguous "invalid" UX states by giving the frontend one canonical close-state handler

Why now:

- repo notes and recent user observations both point at the 40M+ path as the highest-risk correctness area still visible to players/operators

Primary file areas:

- `server/src/Lucky5.Infrastructure/Services/GameService.cs`
- `server/src/Lucky5.Infrastructure/Services/AdminService.cs`
- `server/src/Lucky5.Api/wwwroot/js/game.js`
- `server/tests/Lucky5.Tests/CleanRoomEngineTests.cs`
- `server/tests/Lucky5.Tests/GameServiceRegressionTests.cs`

Acceptance criteria:

- closing at or above 40,000,000 never strands the player in an un-actionable state
- cash-out after machine close is deterministic and idempotent on retry
- admin reset is blocked only when an active round truly exists, not because of stale UI/client state
- machine close remains a gameplay event, not a hidden ledger reset

#### Batch 1B. Long-session continuity and reconnect recovery

Focus:

- stop relying on `sessionStorage` alone for cabinet restoration
- hydrate cabinet state from:
  - `GET /api/Game/machine/{id}/session`
  - `GET /api/Game/machine/{id}/active-round`
- restore the correct phase for:
  - dealt hand waiting for draw
  - drawn win waiting for take-score or double-up
  - active double-up session
- add stale-session exit behavior so users can safely return to lobby when only the machine selection was remembered

Why now:

- the backend already exposes active-round recovery data, but the vanilla frontend is not using it yet
- this is the fastest path to meaningful continuity without waiting for full database persistence

Primary file areas:

- `server/src/Lucky5.Api/wwwroot/js/game.js`
- `server/src/Lucky5.Application/Dtos/ActiveRoundStateDto.cs`
- `server/src/Lucky5.Api/Controllers/GameController.cs`
- `server/tests/Lucky5.Tests/FrontendRegressionTests.cs`

Acceptance criteria:

- refreshing during deal/draw/double-up restores the correct cabinet state
- a saved machine id without an active round no longer traps the player in a confusing game reopen path
- reconnect behavior uses backend truth before frontend local assumptions

#### Batch 1C. Single navigation model and menu cleanup

Focus:

- introduce one authoritative screen-transition helper for lobby, wallet, admin, and game
- keep `BACK TO LOBBY` inside the existing menu panel, but make all entry/exit paths reuse the same helper
- remove remaining inline menu styling and duplicate reset affordances where practical
- centralize machine-close messaging and menu CTA emphasis

Why now:

- `BACK TO LOBBY` is already present in the menu, but transition logic is still scattered across `openGame()`, `showLobby()`, `showWallet()`, auth restore, and `backToLobbyFromGame()`
- this is the clearest path to stabilizing all buttons without redesigning the cabinet

Primary file areas:

- `server/src/Lucky5.Api/wwwroot/index.html`
- `server/src/Lucky5.Api/wwwroot/js/game.js`
- `server/src/Lucky5.Api/wwwroot/css/game.css`

Acceptance criteria:

- every screen change flows through shared navigation helpers
- no critical action depends on an overlay-only edge path with unique state cleanup
- menu markup/styling becomes maintainable without changing the cabinet look

#### Batch 1D. Button and recovery verification sweep

Focus:

- expand regression coverage from partial menu checks to a full button matrix
- verify:
  - lobby nav buttons
  - wallet/admin back buttons
  - game menu buttons
  - machine-close recovery buttons
  - saved-session restore entry path
- add service-level tests for 40M close, cash-out retry, reset-after-close, and active-round resume cases

Why now:

- current frontend regression tests cover jackpot wiring and menu cash-in/out refreshes, but not the full navigation/button matrix

Primary file areas:

- `server/tests/Lucky5.Tests/FrontendRegressionTests.cs`
- `server/tests/Lucky5.Tests/GameServiceRegressionTests.cs`
- `server/tests/Lucky5.Tests/Program.cs`

Acceptance criteria:

- every critical button has at least one regression assertion
- the known reported paths are reproducible in tests before and after fixes
- the console test runner remains the canonical verification path

### Explicitly out of scope for this batch

These should remain separate so this batch stays tight and reversible:

- full durable persistence / database migration
- full React parity project
- new RTP tuning pass
- visible rules changes to double-up, jackpots, or paytable behavior

### Recommended delivery order inside this batch

1. write failing regression tests for 40M close/cash-out/reset and saved-session restore
2. harden backend machine-close and reset semantics
3. add frontend active-round/session hydration
4. centralize navigation/menu transitions
5. finish with the full button verification sweep and doc refresh

### What should come immediately after this batch

Once this batch lands, the next major tranche should be:

1. durable persistence for `MachineLedgerState`, `MachineSessionState`, and `GameRound`
2. admin audit trail and reset-history views
3. simulation/live parity cleanup before any new RTP target claim

---

## Indexed Project Map

## Authoritative docs

- `docs/README.md` — primary developer guide and architecture overview
- `docs/CONTINUATION_GUIDE.md` — fastest handoff path
- `docs/GAME_FEEL_REFERENCE.md` — cabinet UX/aesthetic source of truth
- `docs/FINAL_QA_AND_RTP_PASS_2026-03-13.md` — latest QA + tuning fixes
- `docs/RTP_REBALANCING_ARCHITECTURE.md` — machine policy / RTP shaping architecture
- `docs/REBALANCING_PLAN_85_RTP.md`
- `docs/REBALANCING_RESULTS_85_RTP.md`
- `docs/REBALANCING_SUMMARY_FINAL.md`
- `docs/CLOUD_RUN_DEPLOYMENT.md`
- `AZURE_DEPLOYMENT_GUIDE.md`
- `AZURE_MULTI_REGION_GUIDE.md`
- `docs/ANDROID_BUILD.md`
- `docs/forensics/endpoint_catalog.md`
- `docs/forensics/gameplay_event_catalog.md`
- `docs/forensics/module_map.md`

## Backend structure

- `server/src/Lucky5.Domain/Game/CleanRoom/` — deterministic engine, RTP policy, double-up engine
- `server/src/Lucky5.Domain/Entities/` — rounds, machine ledger/session, users, wallet entries
- `server/src/Lucky5.Application/` — contracts, DTOs, request models
- `server/src/Lucky5.Infrastructure/Services/` — orchestration + in-memory persistence
- `server/src/Lucky5.Api/Controllers/` — REST endpoints
- `server/src/Lucky5.Realtime/` — SignalR hub + connection/heartbeat services

## Live frontend

- `server/src/Lucky5.Api/wwwroot/index.html`
- `server/src/Lucky5.Api/wwwroot/js/game.js`
- `server/src/Lucky5.Api/wwwroot/css/game.css`

## Secondary frontends / clients

- `src/web/` — React/Next cabinet target, currently behind vanilla in UX completeness
- `mobile/` — Capacitor Android wrapper around the web cabinet
- `client/` — Flutter skeleton / inferred parity path, not current primary path

## Tests

- `server/tests/Lucky5.Tests/` — console-runner tests via `dotnet run`, not `dotnet test`

---

## Current State Findings

## 1) Persistence model

Current storage is still volatile and process-local.

### Current authoritative runtime state

- `InMemoryDataStore.Users`
- `InMemoryDataStore.Profiles`
- `InMemoryDataStore.Ledger`
- `InMemoryDataStore.ActiveRounds`
- `InMemoryDataStore.MachineSessions`
- `InMemoryDataStore.MachineLedgers`

Source:

- `server/src/Lucky5.Infrastructure/Services/InMemoryDataStore.cs`

### What this means operationally

- restart/redeploy can wipe machine sessions and ledger history
- Cloud Run / Azure guidance is explicitly single-instance because state is in memory
- multi-region is explicitly unsupported today
- month-scale machine history is not durable yet

Source:

- `docs/CONTINUATION_GUIDE.md`
- `docs/CLOUD_RUN_DEPLOYMENT.md`
- `AZURE_DEPLOYMENT_GUIDE.md`
- `AZURE_MULTI_REGION_GUIDE.md`

---

## 2) Economy / state model is already well-defined

The repo has a strong conceptual model worth preserving:

### Wallet vs machine credit

- wallet balance lives on `MemberProfile.WalletBalance`
- machine credit lives per player+machine in `MachineSessionState.MachineCredits`

Source:

- `server/src/Lucky5.Domain/Entities/MemberProfile.cs`
- `server/src/Lucky5.Domain/Entities/MachineSessionState.cs`
- `docs/CONTINUATION_GUIDE.md`

### Machine session rules

- cash-in in 200,000 increments
- max 1,000,000 per machine session
- cash-out threshold returned as `TotalCashIn * 2`
- machine close tracked separately
- ledger should continue across closes

Source:

- `server/src/Lucky5.Infrastructure/Services/GameService.cs`
- `server/src/Lucky5.Application/Dtos/MachineSessionDto.cs`
- `docs/README.md`
- `docs/CONTINUATION_GUIDE.md`

### Round settlement model

- draw win is deferred
- double-up and take-half mutate payout path
- idempotency is guarded via round settlement fields

Source:

- `server/src/Lucky5.Domain/Entities/GameRound.cs`
- `server/src/Lucky5.Infrastructure/Services/GameService.cs`

This is good news: **the business model is already mature enough to persist directly.**

---

## 3) Admin tooling exists, but is still prototype-grade

### Current backend admin capabilities

- list/search/get users
- admin credit/debit wallet balances
- inspect machines
- inspect machine sessions per machine
- reset machine ledger/session state

Source:

- `server/src/Lucky5.Api/Controllers/AdminController.cs`
- `server/src/Lucky5.Infrastructure/Services/AdminService.cs`
- `server/src/Lucky5.Application/Dtos/AdminDtos.cs`

### Current frontend admin UX limitations

- admin only exposed from lobby nav
- credit/debit still prompt-based
- reset actions use confirm dialogs
- duplicated reset entry points exist

Source:

- vanilla frontend review notes
- `server/src/Lucky5.Api/wwwroot/index.html`
- `server/src/Lucky5.Api/wwwroot/js/game.js`

---

## 4) Player/menu/navigation structure is complete but fragile

### Current live screen structure

- auth
- lobby
- wallet
- admin
- game
- overlay game menu

The vanilla app is the real UX source of truth today.

### Current risks

- navigation is duplicated across direct DOM toggles
- menu styling is partly inline / brittle
- “Back to Lobby” is hidden behind overlay menu flow
- machine-close recovery messaging is scattered
- sessionStorage machine restore can trap users back into game unexpectedly
- React cabinet does not yet match vanilla navigation/menu parity

Source:

- `server/src/Lucky5.Api/wwwroot/index.html`
- `server/src/Lucky5.Api/wwwroot/js/game.js`
- `server/src/Lucky5.Api/wwwroot/css/game.css`
- `src/web/CLAUDE.md`

---

## 5) Supporting utilities already point to the next completion layer

The repo already contains the beginnings of a proper completion stack:

- deployment guides for Cloud Run and Azure
- Android wrapper guide
- SignalR contract docs
- forensics mapping for clean-room parity
- RTP tuning documentation
- regression tests for jackpot UI and gameplay edge cases

What is missing is the next layer of utilities:

- persistent data migrations / schema ownership
- recovery tooling for active rounds
- structured admin audit views
- button/navigation verification coverage
- exact service-state inspection/debug utilities
- more formal simulation parity tooling for double-up EV

---

## vNext Product Goals

Lucky5 vNext should aim to satisfy all of the following:

1. **Durable machine history**
2. **Durable player machine sessions**
3. **Recoverable long-running sessions**
4. **Reliable, predictable cabinet navigation**
5. **Safer admin operations**
6. **Operationally valid single-region production**
7. **A cleaner bridge to future scale-out / multi-region**
8. **Better tooling for regression, auditing, and balancing**

---

## Recommended vNext Workstreams

## Track A — Persistence & Recovery Foundation (P0)

### Goal

Replace volatile authoritative state with durable storage while preserving existing gameplay rules and economy semantics.

### Persist first

1. `MachineLedgerState`
2. `MachineSessionState`
3. `GameRound` (at least active + recent settled rounds)
4. `WalletLedgerEntry`
5. `User`
6. `MemberProfile`

### Why this order

- machine-ledger and machine-session durability are explicitly the biggest blocker
- round durability is needed for reconnect/recovery and anti-duplication
- wallet/user/profile persistence is straightforward and unlocks cleaner admin/reporting flows

### Suggested storage boundary

Introduce repository interfaces beneath services so that:

- `GameService`
- `AuthService`
- `AdminService`

stop directly depending on `InMemoryDataStore` as the long-term source of truth.

### Recommended persistence shape

**Phase A1 — Hybrid persistence**

- keep in-memory caching where useful
- add durable backing store for authoritative writes
- hydrate cache on startup

**Phase A2 — Repository-first**

- move services to repository interfaces
- use in-memory implementation only for tests/dev fallback

### Must-have behaviors

- restart-safe machine ledger history
- restart-safe machine credit sessions
- active round recovery on reconnect
- idempotent payout/cashout on retry
- machine close remains gameplay event, not ledger reset
- reset operations become explicit durable actions, not just memory wipes

### File areas impacted

- `server/src/Lucky5.Infrastructure/Services/InMemoryDataStore.cs`
- `server/src/Lucky5.Infrastructure/Services/GameService.cs`
- `server/src/Lucky5.Infrastructure/Services/AdminService.cs`
- `server/src/Lucky5.Infrastructure/Services/AuthService.cs`
- `server/src/Lucky5.Domain/Entities/*`
- new repository / persistence implementations under `server/src/Lucky5.Infrastructure/`

### Acceptance criteria

- restart does not erase machine ledger
- restart does not erase machine session credits
- active round can be resumed or safely closed after restart
- admin machine inspection reflects persisted truth
- cash-in/cash-out/double-up settlements remain idempotent

---

## Track B — Navigation, Menu, and Cabinet UX Hardening (P1)

### Goal

Make every player/admin route explicit, testable, and consistent.

### Core tasks

#### B1. Introduce a single frontend router/state transition layer

Refactor all screen switching into one authoritative helper.

Current scattered areas:

- `openGame()`
- `showLobby()`
- `showWallet()`
- `showAdmin()`
- logout/reset transitions
- menu open/close transitions

### Why

This is the root cause behind button drift and broken-path risk.

#### B2. Normalize in-game menu structure

The menu should remain part of the cabinet experience, but its actions need clearer prioritization.

Recommended shape:

- CASH IN
- CASH OUT
- BACK TO LOBBY / EXIT MACHINE
- RESET MACHINE (admin only)
- LOGOUT
- CLOSE

### Why

Currently “Back to Lobby” is functionally available but too hidden/fragile.

#### B3. Centralize machine-closed recovery UX

Create one helper/state block that handles:

- machine closed status
- allowable actions
- correct menu CTA emphasis
- consistent message copy

### Why

Current machine-close handling is scattered and can feel opaque.

#### B4. Remove inline-style menu brittleness

Move remaining inline menu structure/styling into CSS and keep HTML semantic.

#### B5. Decide vanilla vs React ownership

Either:

- keep vanilla as canonical and React as future rebuild target, or
- commit to React parity work as a formal project

But do not keep them in ambiguous dual ownership.

### File areas impacted

- `server/src/Lucky5.Api/wwwroot/index.html`
- `server/src/Lucky5.Api/wwwroot/js/game.js`
- `server/src/Lucky5.Api/wwwroot/css/game.css`
- optionally `src/web/components/lucky5-cabinet.tsx`

### Acceptance criteria

- every screen transition uses one shared routing helper
- all lobby/game/wallet/admin/menu buttons are covered by a verification checklist
- machine-close CTA path is obvious and consistent
- refresh/reconnect does not trap players unexpectedly in game view
- no hidden critical navigation path depends on a single overlay-only action

---

## Track C — Admin Operations Upgrade (P1/P2)

### Goal

Move admin flows from prototype controls to trustworthy operational tools.

### Core tasks

#### C1. Replace prompt/confirm flows with inline admin controls

Needed for:

- wallet credit/debit
- machine reset
- potentially jackpot/rank inspection or machine close/session actions later

#### C2. Add admin audit views

At minimum expose:

- recent wallet adjustments
- machine reset history
- player machine cash-in/cash-out history
- reason strings and acting admin identity

#### C3. Separate reset semantics clearly

Distinguish:

- machine gameplay close
- player machine cash-out
- machine ledger reset
- session reset
- emergency round clear

### Why

These concepts are currently too easy to conflate.

#### C4. Add durable admin action records

Every admin mutation should leave a durable audit trail.

### File areas impacted

- `server/src/Lucky5.Api/Controllers/AdminController.cs`
- `server/src/Lucky5.Infrastructure/Services/AdminService.cs`
- `server/src/Lucky5.Application/Dtos/AdminDtos.cs`
- `server/src/Lucky5.Api/wwwroot/index.html`
- `server/src/Lucky5.Api/wwwroot/js/game.js`

### Acceptance criteria

- no admin-critical action depends on `prompt()` or `confirm()`
- every admin mutation has a visible reason + durable audit entry
- reset actions are semantically distinct in UI and backend
- admins can inspect per-machine and per-user state without ambiguity

---

## Track D — Supporting Utilities & Delivery Readiness (P2)

### Goal

Make Lucky5 easier to operate, verify, and evolve.

### D1. Persistence bootstrap / schema utilities

Add:

- migration scripts
- seed data strategy
- dev reset tooling
- environment-specific bootstrap

### D2. Gameplay recovery utilities

Add:

- active round inspection endpoint(s)
- stale round cleanup policy
- operator-safe replay/recovery guidance

### D3. Frontend verification utilities

Add a button and flow verification checklist covering:

- lobby buttons
- wallet buttons
- admin buttons
- all game menu actions
- machine-close states
- reconnect/refresh restore states

### D4. Test expansion

Add coverage for:

- persistence round-trip
- restart recovery
- machine session cashout threshold rules
- close/reset/cashout interactions
- navigation reliability
- menu action visibility across phases

### D5. Formal simulation parity refresh

Per the QA docs, the next balancing step should refresh the simulation harness to match live service behavior exactly, especially around double-up EV.

Sources:

- `docs/FINAL_QA_AND_RTP_PASS_2026-03-13.md`
- `Arcade Game RNG Simulation Model.md`

### Acceptance criteria

- one-command dev bootstrap restores a known valid state
- regression coverage exists for persistence + nav + machine-close flows
- simulation assumptions are documented against live service rules
- deployment docs no longer rely on “state survives only while process lives”

---

## Proposed Delivery Sequence

## Phase 1 — Persistence skeleton

- define persistence interfaces
- implement durable storage for users/profiles/wallet ledger
- implement durable storage for machine ledgers and machine sessions
- keep service logic behavior unchanged as much as possible

## Phase 2 — Round durability and recovery

- persist active rounds
- support recovery of active round state
- define stale/incomplete round handling rules

## Phase 3 — Frontend navigation/menu refactor

- central router/helper
- central machine-close UX helper
- menu cleanup
- button verification pass

## Phase 4 — Admin UX upgrade

- inline forms/panels
- audit views
- clearer reset semantics

## Phase 5 — Utilities and balancing support

- migration/bootstrap tools
- deeper tests
- simulation parity refresh
- deployment doc updates for new durable state model

---

## Recommended Definition of Done for vNext

Lucky5 vNext should not be considered complete until all of the following are true:

- authoritative runtime state is durable across restart/redeploy
- machine sessions survive process restarts
- machine ledgers survive process restarts
- wallet history is durable and inspectable
- active rounds can be recovered or safely reconciled
- all cabinet/lobby/admin buttons have a single verified navigation model
- machine-close / cashout / reset semantics are unambiguous in UI and backend
- admin actions are auditable and no longer rely on prompt/confirm dialogs
- deployment guidance can safely describe the app as durable in single-region production
- the React path is either promoted with parity scope or explicitly demoted to secondary status

---

## Highest-Value First Moves

If only a small amount of vNext work can be started immediately, do these first:

1. **persist `MachineLedgerState` and `MachineSessionState`**
2. **add one authoritative frontend router/state transition helper**
3. **centralize machine-close recovery behavior**
4. **replace prompt/confirm admin mutations**
5. **add persistence + navigation regression coverage**

That sequence gives the biggest completion gain for the least architectural waste.

---

## Key Source References

### Architecture / source of truth

- `docs/README.md`
- `docs/CONTINUATION_GUIDE.md`
- `docs/CLAUDE.md`

### Persistence and services

- `server/src/Lucky5.Infrastructure/Services/InMemoryDataStore.cs`
- `server/src/Lucky5.Infrastructure/Services/GameService.cs`
- `server/src/Lucky5.Infrastructure/Services/AdminService.cs`
- `server/src/Lucky5.Infrastructure/Services/AuthService.cs`

### Domain model

- `server/src/Lucky5.Domain/Entities/MachineLedgerState.cs`
- `server/src/Lucky5.Domain/Entities/MachineSessionState.cs`
- `server/src/Lucky5.Domain/Entities/GameRound.cs`
- `server/src/Lucky5.Domain/Entities/MemberProfile.cs`
- `server/src/Lucky5.Domain/Entities/User.cs`
- `server/src/Lucky5.Domain/Entities/WalletLedgerEntry.cs`

### API surface

- `server/src/Lucky5.Api/Controllers/GameController.cs`
- `server/src/Lucky5.Api/Controllers/AuthController.cs`
- `server/src/Lucky5.Api/Controllers/AdminController.cs`

### Live frontend

- `server/src/Lucky5.Api/wwwroot/index.html`
- `server/src/Lucky5.Api/wwwroot/js/game.js`
- `server/src/Lucky5.Api/wwwroot/css/game.css`

### Deployment / platform limits

- `docs/CLOUD_RUN_DEPLOYMENT.md`
- `AZURE_DEPLOYMENT_GUIDE.md`
- `AZURE_MULTI_REGION_GUIDE.md`

### Balancing / QA

- `docs/FINAL_QA_AND_RTP_PASS_2026-03-13.md`
- `docs/RTP_REBALANCING_ARCHITECTURE.md`
- `Arcade Game RNG Simulation Model.md`

Current Persistence Model
In-memory store as source of truth (
InMemoryDataStore.cs) – Users, machines, ledger entries, sessions, and rounds all live in shared dictionaries without a durable database. Line references: repeated dictionary declarations around InMemoryDataStore, e.g., public readonly Dictionary<Guid, MemberProfile> and ledger/session collections near top of file. Because all services read/write this singleton, state resets when the process restarts, and concurrency control relies purely on in-memory locking.
Service contracts wrap DTOs/requests (Lucky5.Application/Contracts/* and Dtos/*) ensure controllers never reach domain entities directly. Examples: IAdminService (lines ~15-25) exposes AdminCreditAsync, ResetMachineAsync; DTOs like AdminMachineDto live under Dtos and are returned by controllers (GameController lines 37‑145).
No persistence segregation by bounded context – Admin, game, and auth flows all share same datastore and services via dependency injection; there’s no repository abstraction for future DB swap.
Admin Capabilities
Endpoints (AdminController & GameController) span user listing/search (AdminController lines 13‑36), crediting and machine resets (AdminController lines 38‑68, GameController lines 137‑145), and machine inspection (AdminController lines 46‑66).
Admin service surface (
AdminService.cs, referenced via controller) returns DTOs such as AdminMachineDto and AdminUserDto to avoid leaking entity internals; key operations include ListMachinesAsync, ResetMachineAsync, AdminCreditAsync (method implementations around lines 70‑210).
Token-guarded flows – Both admin controllers require RequireAdminRole() (e.g., AdminController lines 13, 21, 30, 38, etc., GameController line 141) so only authenticated admins manipulate machine/session state.
Session / Ledger Model
Session tracking in entities – MachineSessionState (
MachineSessionState.cs) stores TotalCashIn, MachineCredits, IsMachineClosed (lines 7‑11). MachineLedgerState and WalletLedgerEntry (entities in Lucky5.Domain/Entities) capture credit history; domain rounds (
GameRound.cs) hold betting details per game.
Game service exposes session APIs (GameController lines 29‑133; service implementations around 
GameService.cs, e.g., GetMachineSessionAsync, CashInAsync, DealAsync, DrawAsync, DoubleUpAsync, GetActiveRoundAsync near lines ~31‑750) that mutate session/ledger state purely within CleanRoom engine results.
Ledger snapshots provided to frontend via DTOs (WalletLedgerEntryDto under Application/Dtos and used in AuthController MemberHistory lines 51‑57). Auth service endpoint MemberHistory (AuthController lines 51‑57) simply returns stored ledger entries for the requesting user.
Pain Points
Volatile state due to in-memory-only persistence – Any restart wipes all machines, sessions, ledger entries, and admin actions (InMemoryDataStore is process-lifetime; no disk/backing store).
Tight coupling between services and datastore – Game, auth, admin services all directly mutate the same dictionaries, making future sharding/migration harder (see GameService, AuthService, AdminService constructors all taking InMemoryDataStore).
Security logic duplicated in controllers – Each action manually calls RequireAdminRole()/RequireUserId(), suggesting policy/filter centralization would be better for vNext.
Lack of transactional boundaries – Complex flows like CashIn/CashOut (GameController lines 37‑50) adjust machines, sessions, and ledger entries without explicit transaction or consistency guard; rolling this out to persistent store would require new infrastructure.
DTO-heavy responses mask domain needs – While safe for controllers, DTOs (e.g., AdminMachineDto, MachineSessionDto, WalletLedgerEntryDto) may miss audit fields needed for future reporting (review DTO definitions under Lucky5.Application/Dtos).
vNext Priorities
Introduce durable persistence layer (Postgres/Redis) for InMemoryDataStore entities: specify table/collection schema for users, sessions, ledgers, rounds. Prioritize MemberProfile, MachineSessionState, and ledger entries (WalletLedgerEntry) as the minimal set to preserve continuity.
Decouple services from shared store by defining repository interfaces per aggregate (e.g., IMachineRepository, ISessionRepository) and wiring them through DI. Start with identity/machine/session flows used across Game/Admin controllers to keep feature parity.
Centralize admin authorization using policies or attribute-based filters rather than per-action checks so future endpoints automatically inherit guardrails.
Audit/ledger integrity – Enhance WalletLedgerEntry storage with immutability/timestamps and expose change tracking to admin endpoints (AdminController.AdminCreditAsync, AuthController.TransferBalanceAsync, etc.) for regulatory readiness.
Session resiliency across restarts – Persist the MachineSessionState entity so ongoing sessions survive server restarts; consider snapshotting MachineCredits, TotalCashIn, IsMachineClosed before loading Lucky5.Domain/Game/CleanRoom engine.
Clarify DTO contracts in Lucky5.Application/Dtos (e.g., MachineSessionDto, WalletLedgerEntryDto, AdminUserDto) to ensure vNext clients get all necessary fields for auditing and UX state.
