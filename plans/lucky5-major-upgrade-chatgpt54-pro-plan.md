# Plan: Lucky5 Major Upgrade for ChatGPT 5.4 Pro

**Generated**: 2026-04-04
**Complexity**: High
**Primary target**: [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx), [`src/web/app/globals.css`](src/web/app/globals.css), [`server/src/Lucky5.Infrastructure/Services/GameService.cs`](server/src/Lucky5.Infrastructure/Services/GameService.cs), [`server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs`](server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs), [`server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs`](server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs)

## Overview

This plan converts the requested Lucky5 next-version upgrade into a strict, step-by-step execution brief for ChatGPT 5.4 Pro so implementation stays focused, repo-grounded, and resistant to wandering or restriction loops.

The upgrade is organized into **5 major workstreams** executed in this order:

1. **Cabinet visual parity with the APK clone**
2. **Double-up layout and interaction redesign**
3. **Systems polish, responsiveness, and Redis-backed hot-path caching**
4. **Double-up outcome presentation correctness**
5. **RTP rebalance with stronger low-sample smoothing and reduced volatility**

This ordering matches the user’s priorities while separating overlapping code areas into clean ownership boundaries.

## Grounded Repo Findings

### Frontend state

- The active web cabinet is a single large component in [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx).
- The active web styling is centralized in [`src/web/app/globals.css`](src/web/app/globals.css).
- Local frontend guidance explicitly says the cabinet is still missing parity features and remains a single-component implementation in [`src/web/CLAUDE.md`](src/web/CLAUDE.md).

### Legacy visual reference already in repo

- The legacy cabinet implementation already contains jackpot display behavior and double-up flow references in [`server/src/Lucky5.Api/wwwroot/js/game.js`](server/src/Lucky5.Api/wwwroot/js/game.js).
- Existing cabinet art assets already exist in [`server/src/Lucky5.Api/wwwroot/assets/images/`](server/src/Lucky5.Api/wwwroot/assets/images/).
- Screenshot evidence for APK fidelity exists in [`screenshots/`](screenshots), especially [`screenshots/Screenshot 2026-03-11 014751.png`](screenshots/Screenshot%202026-03-11%20014751.png).

### Double-up backend state

- The authoritative double-up endpoints live in [`server/src/Lucky5.Api/Controllers/GameController.cs`](server/src/Lucky5.Api/Controllers/GameController.cs).
- Double-up application responses are shaped by [`server/src/Lucky5.Application/Dtos/DoubleUpResultDto.cs`](server/src/Lucky5.Application/Dtos/DoubleUpResultDto.cs).
- Session resolution logic is in [`server/src/Lucky5.Infrastructure/Services/GameService.cs`](server/src/Lucky5.Infrastructure/Services/GameService.cs).
- Deterministic double-up rules live in [`server/src/Lucky5.Domain/Game/CleanRoom/Lucky5DoubleUpEngine.cs`](server/src/Lucky5.Domain/Game/CleanRoom/Lucky5DoubleUpEngine.cs).

### Redis state today

- Redis is wired today only as a persistence snapshot store in [`server/src/Lucky5.Infrastructure/Services/ServiceCollectionExtensions.cs`](server/src/Lucky5.Infrastructure/Services/ServiceCollectionExtensions.cs) and [`server/src/Lucky5.Infrastructure/Services/RedisPersistentStateStore.cs`](server/src/Lucky5.Infrastructure/Services/RedisPersistentStateStore.cs).
- It is **not yet a hot-path response cache** for machine state or active-round lookups.

### RTP control today

- Current RTP knobs are centralized in [`server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs`](server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs).
- Control logic and smoothing live in [`server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs`](server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs).
- Simulation support already exists in [`server/src/Lucky5.Simulation/Program.cs`](server/src/Lucky5.Simulation/Program.cs).

## Locked Product Decisions

These were clarified and should be treated as binding assumptions for implementation:

- **Visual fidelity**: near-1:1 APK-inspired cabinet feel using [`screenshots/`](screenshots) as the source of truth
- **Double-up controls**: keep `SWITCH` only if the APK evidence supports it
- **Redis scope first**: cache machine state and active-round lookups before broader caching
- **RTP direction**: keep target RTP around `85%`, but smooth early behavior much more aggressively and reduce extreme swings

## Non-Negotiable Architecture Rules

1. **Do not move core game rules out of CleanRoom**. Any rule change must remain in [`server/src/Lucky5.Domain/Game/CleanRoom/`](server/src/Lucky5.Domain/Game/CleanRoom).
2. **Do not modernize the product into a generic casino UI**. Preserve cabinet feel from [`docs/GAME_FEEL_REFERENCE.md`](docs/GAME_FEEL_REFERENCE.md).
3. **Backend remains authoritative** for payouts, round state, machine state, and double-up outcomes.
4. **Frontend presentation noise must never contradict the server result**.
5. **One owner per file** during implementation.

## ChatGPT 5.4 Pro Execution Brief

Use the following as the instruction block for the implementation agent.

### System-style instruction

You are implementing the Lucky5 major upgrade in a real repository. Do not wander into open-ended brainstorming. Do not rewrite unrelated systems. Do not get stuck in policy loops. Work strictly in the phases below, verify each phase, and stop only at explicit review gates.

### Mission

Implement the next major Lucky5 upgrade with these priorities, in this exact order:

1. Upgrade the web cabinet to near-1:1 APK fidelity using [`screenshots/`](screenshots) and the legacy cabinet reference in [`server/src/Lucky5.Api/wwwroot/js/game.js`](server/src/Lucky5.Api/wwwroot/js/game.js)
2. Redesign double-up so the viewport stays fixed and shows 5 cards per page instead of a moving trail
3. Improve overall smoothness and make Redis actually useful for machine-state and active-round hot reads in Azure
4. Remove fake client-side double-up stop behavior so the player only sees the authoritative server card outcome
5. Rebalance RTP around 85 percent with stronger low-sample smoothing and smaller early volatility swings

### Mandatory workflow

1. Inspect before editing
2. Create or refresh a short task list
3. Implement one workstream at a time
4. Run the smallest relevant verification after each workstream
5. Do not claim completion without evidence
6. If a decision is ambiguous, prefer APK evidence and existing repo conventions over invention

### Mandatory read set before coding

- [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx)
- [`src/web/app/globals.css`](src/web/app/globals.css)
- [`src/web/CLAUDE.md`](src/web/CLAUDE.md)
- [`server/src/Lucky5.Api/wwwroot/js/game.js`](server/src/Lucky5.Api/wwwroot/js/game.js)
- [`server/src/Lucky5.Infrastructure/Services/GameService.cs`](server/src/Lucky5.Infrastructure/Services/GameService.cs)
- [`server/src/Lucky5.Domain/Game/CleanRoom/Lucky5DoubleUpEngine.cs`](server/src/Lucky5.Domain/Game/CleanRoom/Lucky5DoubleUpEngine.cs)
- [`server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs`](server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs)
- [`server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs`](server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs)
- [`server/tests/Lucky5.Tests/FrontendRegressionTests.cs`](server/tests/Lucky5.Tests/FrontendRegressionTests.cs)
- [`server/tests/Lucky5.Tests/GameServiceRegressionTests.cs`](server/tests/Lucky5.Tests/GameServiceRegressionTests.cs)
- [`server/tests/Lucky5.Tests/CleanRoomEngineTests.cs`](server/tests/Lucky5.Tests/CleanRoomEngineTests.cs)

### Restrictions to avoid drift

- Do not split CleanRoom logic across infrastructure or frontend files
- Do not add random frontend-only card reveal logic that can diverge from server output
- Do not add broad caching everywhere; start only with machine state and active-round hot paths
- Do not redesign the whole app shell before cabinet parity is improved
- Do not change RTP target away from approximately 85 percent unless explicitly approved

## File Ownership Plan

### Workstream A — Cabinet UI parity owner

**Owns only:**

- [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx)
- [`src/web/app/globals.css`](src/web/app/globals.css)

**Reads but does not edit:**

- [`server/src/Lucky5.Api/wwwroot/js/game.js`](server/src/Lucky5.Api/wwwroot/js/game.js)
- [`screenshots/`](screenshots)

### Workstream B — Double-up contract and backend behavior owner

**Owns only:**

- [`server/src/Lucky5.Application/Dtos/DoubleUpResultDto.cs`](server/src/Lucky5.Application/Dtos/DoubleUpResultDto.cs)
- [`server/src/Lucky5.Api/Controllers/GameController.cs`](server/src/Lucky5.Api/Controllers/GameController.cs)
- [`server/src/Lucky5.Infrastructure/Services/GameService.cs`](server/src/Lucky5.Infrastructure/Services/GameService.cs)
- [`server/src/Lucky5.Domain/Game/CleanRoom/Lucky5DoubleUpEngine.cs`](server/src/Lucky5.Domain/Game/CleanRoom/Lucky5DoubleUpEngine.cs)

### Workstream C — Redis hot-path caching owner

**Owns only:**

- [`server/src/Lucky5.Infrastructure/Services/ServiceCollectionExtensions.cs`](server/src/Lucky5.Infrastructure/Services/ServiceCollectionExtensions.cs)
- [`server/src/Lucky5.Infrastructure/Services/RedisPersistentStateStore.cs`](server/src/Lucky5.Infrastructure/Services/RedisPersistentStateStore.cs)
- new cache service interfaces and implementations under [`server/src/Lucky5.Infrastructure/Services/`](server/src/Lucky5.Infrastructure/Services)
- cache usage points in [`server/src/Lucky5.Infrastructure/Services/GameService.cs`](server/src/Lucky5.Infrastructure/Services/GameService.cs)

### Workstream D — RTP policy tuning owner

**Owns only:**

- [`server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs`](server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs)
- [`server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs`](server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs)
- [`server/src/Lucky5.Simulation/Program.cs`](server/src/Lucky5.Simulation/Program.cs) if needed for output/reporting only

### Workstream E — Test and verification owner

**Owns only:**

- [`server/tests/Lucky5.Tests/FrontendRegressionTests.cs`](server/tests/Lucky5.Tests/FrontendRegressionTests.cs)
- [`server/tests/Lucky5.Tests/GameServiceRegressionTests.cs`](server/tests/Lucky5.Tests/GameServiceRegressionTests.cs)
- [`server/tests/Lucky5.Tests/CleanRoomEngineTests.cs`](server/tests/Lucky5.Tests/CleanRoomEngineTests.cs)
- any new focused regression tests in [`server/tests/Lucky5.Tests/`](server/tests/Lucky5.Tests)

## Interface Contract Rules

1. If Workstream A needs new frontend fields, Workstream B owns the response contract in [`server/src/Lucky5.Application/Dtos/DoubleUpResultDto.cs`](server/src/Lucky5.Application/Dtos/DoubleUpResultDto.cs).
2. If Workstream C adds cache wrappers around game state reads, Workstream B must not implement a second caching path.
3. If Workstream D changes policy metrics needed by telemetry, expose them through backend DTOs first, then let Workstream A render them.
4. Workstream E does not redefine behavior; it codifies expected behavior after A through D agree on contracts.

## Sprint 1 — Visual Parity Foundation

**Goal**: make the web cabinet look and feel much closer to the APK before changing deeper interactions.

**Demo/Validation**:

- Cabinet layout visually resembles [`screenshots/Screenshot 2026-03-11 014751.png`](screenshots/Screenshot%202026-03-11%20014751.png)
- Lower jackpot area and control block match the original hierarchy and proportions more closely
- No gameplay rules changed yet

### Task 1.1 — Build a screenshot-to-UI diff checklist

- **Location**: [`screenshots/`](screenshots), [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx), [`src/web/app/globals.css`](src/web/app/globals.css), [`server/src/Lucky5.Api/wwwroot/js/game.js`](server/src/Lucky5.Api/wwwroot/js/game.js)
- **Description**: Extract exact cabinet sections from screenshot evidence: jackpot lower strip, hold row, action button row, lower menu cluster, card spacing, typography rhythm, and panel framing.
- **Acceptance Criteria**:
  - Clear checklist exists for each visual mismatch
  - APK-derived elements are separated from modern web-only elements
- **Validation**:
  - Manual visual checklist review against screenshots

### Task 1.2 — Refactor cabinet markup without changing game logic

- **Location**: [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx)
- **Description**: Break the single JSX block into clearly marked cabinet sections while preserving existing behavior.
- **Dependencies**: Task 1.1
- **Acceptance Criteria**:
  - Distinct markup zones for paytable, jackpot strip, playfield, double-up area, and lower controls
  - No API behavior changes
- **Validation**:
  - Cabinet still renders and existing controls still map to current handlers

### Task 1.3 — Rebuild cabinet styling for APK-like lower panel fidelity

- **Location**: [`src/web/app/globals.css`](src/web/app/globals.css)
- **Description**: Move the current generic panel styling toward the APK control-block composition: gold/orange controls, compact jackpot strip, stronger cabinet frame, and more authentic spacing.
- **Dependencies**: Task 1.2
- **Acceptance Criteria**:
  - Bottom jackpot area resembles APK structure more closely
  - Control panel reads as cabinet hardware rather than dashboard UI
- **Validation**:
  - Screenshot comparison at common viewport sizes

## Sprint 2 — Double-Up Layout Redesign

**Goal**: replace the moving trail/parallax-style behavior with fixed, page-based double-up presentation.

**Demo/Validation**:

- Double-up screen no longer scrolls or shifts as levels advance
- One page shows exactly 5 cards worth of progression slots
- Advancing past card 5 opens the next page cleanly

### Task 2.1 — Define fixed-page double-up view model

- **Location**: [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx), [`server/src/Lucky5.Application/Dtos/DoubleUpResultDto.cs`](server/src/Lucky5.Application/Dtos/DoubleUpResultDto.cs)
- **Description**: Decide what frontend state is needed to render 5-card pages: current page index, slot position in page, historical resolved cards, and next dealer state.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**:
  - Frontend model supports fixed 5-slot layout
  - No fake inferred state is required if server can provide authoritative data
- **Validation**:
  - State diagram matches real round progression

### Task 2.2 — Replace 2-card panel with 5-slot fixed page layout

- **Location**: [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx), [`src/web/app/globals.css`](src/web/app/globals.css)
- **Description**: Replace the current dealer/challenger pair panel with a fixed five-slot progression strip per page.
- **Dependencies**: Task 2.1
- **Acceptance Criteria**:
  - 5 slots are visible simultaneously
  - Layout stays fixed while individual slots update
  - Page transitions happen only after the fifth resolved card
- **Validation**:
  - Manual playthrough of 6 plus successful steps

### Task 2.3 — Confirm whether `SWITCH` survives in APK-parity mode

- **Location**: [`screenshots/`](screenshots), [`server/src/Lucky5.Api/wwwroot/js/game.js`](server/src/Lucky5.Api/wwwroot/js/game.js), [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx)
- **Description**: Use screenshot evidence and legacy cabinet behavior to decide whether `SWITCH` stays visible, moves, or becomes conditional.
- **Dependencies**: Task 2.2
- **Acceptance Criteria**:
  - Decision is explicitly documented in code comments or plan notes
  - UI matches the chosen parity rule
- **Validation**:
  - Review against screenshot evidence

## Sprint 3 — Systems Smoothness and Redis Hot-Path Caching

**Goal**: improve responsiveness and make Redis useful beyond snapshot persistence.

**Demo/Validation**:

- Machine state requests reuse Redis-backed hot data where safe
- Active-round lookup path benefits from caching or indexed lookup strategy
- Azure deployment keeps working with Redis enabled

### Task 3.1 — Add cache abstraction for machine state and active-round reads

- **Location**: [`server/src/Lucky5.Infrastructure/Services/`](server/src/Lucky5.Infrastructure/Services)
- **Description**: Introduce a focused cache service for read-mostly machine state and active-round snapshots instead of overloading snapshot persistence.
- **Dependencies**: Sprint 2 contract decisions
- **Acceptance Criteria**:
  - Cache responsibilities are separate from full snapshot persistence
  - Read and invalidation paths are explicit
- **Validation**:
  - Unit tests for cache get, set, invalidate

### Task 3.2 — Cache machine state hot path

- **Location**: [`server/src/Lucky5.Infrastructure/Services/GameService.cs`](server/src/Lucky5.Infrastructure/Services/GameService.cs)
- **Description**: Identify machine-state read methods and wrap them in cache-aside logic with targeted invalidation on deal, draw, jackpot updates, double-up, take-half, and cashout.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Machine state cache is invalidated on all state-changing mutations
  - No stale jackpot or phase display after user actions
- **Validation**:
  - Integration tests around machine state freshness

### Task 3.3 — Cache or index active-round lookup path

- **Location**: [`server/src/Lucky5.Infrastructure/Services/GameService.cs`](server/src/Lucky5.Infrastructure/Services/GameService.cs), [`server/src/Lucky5.Infrastructure/Services/InMemoryDataStore.cs`](server/src/Lucky5.Infrastructure/Services/InMemoryDataStore.cs)
- **Description**: Improve active-round retrieval latency either with Redis-assisted cache-aside or a tighter in-memory index plus Redis mirror where useful.
- **Dependencies**: Task 3.1
- **Acceptance Criteria**:
  - Active round reads are cheaper and well-instrumented
  - Cache invalidation is tied to round settlement
- **Validation**:
  - Regression tests for round progression and recovery

### Task 3.4 — Add cache observability and Azure-safe defaults

- **Location**: [`server/src/Lucky5.Infrastructure/Services/ServiceCollectionExtensions.cs`](server/src/Lucky5.Infrastructure/Services/ServiceCollectionExtensions.cs)
- **Description**: Add configuration for TTLs, namespacing, and fallbacks so Azure auto-deploy remains safe if Redis is slow or unavailable.
- **Dependencies**: Tasks 3.2 and 3.3
- **Acceptance Criteria**:
  - Cache outage degrades gracefully
  - Redis connection setup remains Azure-compatible
- **Validation**:
  - Start-up and degraded-mode verification

## Sprint 4 — Double-Up Reveal Correctness

**Goal**: eliminate fake local stop behavior and reveal only the authoritative server outcome card.

**Demo/Validation**:

- On `BIG` or `SMALL`, the client does not theatrically stop on a random card and then swap to the server card
- The only resolved challenger card shown is the real one from the backend

### Task 4.1 — Audit and remove misleading presentation noise from double-up resolution

- **Location**: [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx), [`server/src/Lucky5.Application/Dtos/DoubleUpResultDto.cs`](server/src/Lucky5.Application/Dtos/DoubleUpResultDto.cs)
- **Description**: Separate harmless suspense timing from any incorrect visual randomization that misrepresents the actual challenger card.
- **Dependencies**: Sprint 2 fixed-page model
- **Acceptance Criteria**:
  - No incorrect pre-reveal random stop card is shown
  - Optional suspense does not contradict the server response
- **Validation**:
  - Manual high-speed repeated double-up tests

### Task 4.2 — Make server response sufficient for authoritative reveal UX

- **Location**: [`server/src/Lucky5.Infrastructure/Services/GameService.cs`](server/src/Lucky5.Infrastructure/Services/GameService.cs), [`server/src/Lucky5.Application/Dtos/DoubleUpResultDto.cs`](server/src/Lucky5.Application/Dtos/DoubleUpResultDto.cs)
- **Description**: Ensure the response fully supports the frontend fixed-page reveal sequence without requiring any guessed local transition state.
- **Dependencies**: Task 4.1
- **Acceptance Criteria**:
  - Frontend can render the resolved slot directly from DTO data
  - Win, lose, safe fail, and machine-closed outcomes all remain explicit
- **Validation**:
  - API contract review and tests

## Sprint 5 — RTP Rebalance and Low-Sample Stability

**Goal**: keep RTP near 85 percent while reducing wild swings, especially when the sample size is still small.

**Demo/Validation**:

- Simulation shows tighter early-round RTP variance
- Cold/hot transitions are less violent
- No regression in deterministic engine behavior

### Task 5.1 — Re-tune low-sample smoothing inputs

- **Location**: [`server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs`](server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs), [`server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs`](server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs)
- **Description**: Increase the effective influence of the target RTP during low sample sizes by tuning smoothing window, minimum samples for control, warmup rounds, convergence horizon, jitter amplitude, and drift clamps.
- **Dependencies**: prior sprints complete enough to avoid confounding UI bugs with RTP evaluation
- **Acceptance Criteria**:
  - Early-round controller reacts more slowly and more smoothly
  - Smoothed drift dominates raw drift during small samples
- **Validation**:
  - Simulation runs and numerical comparison against previous baseline

### Task 5.2 — Reduce extreme mode swings and payout corrections

- **Location**: [`server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs`](server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs)
- **Description**: Reduce oscillation by softening correction gain, cap-pressure effect, streak boost intensity, and deck alteration aggressiveness.
- **Dependencies**: Task 5.1
- **Acceptance Criteria**:
  - Mode switching happens less abruptly
  - RTP correction still converges but with fewer spikes
- **Validation**:
  - Simulation over small, medium, and large round counts

### Task 5.3 — Rebalance without changing core target identity

- **Location**: [`server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs`](server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs)
- **Description**: Keep the headline target near 85 percent while redistributing how aggressively the system reaches it during the first few hundred rounds.
- **Dependencies**: Task 5.2
- **Acceptance Criteria**:
  - Target RTP remains approximately 85 percent
  - Early volatility is meaningfully lower
- **Validation**:
  - Simulation report and regression tests

## Testing Strategy

### Required verification after each sprint

- Frontend cabinet render smoke check for [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx)
- Backend build for [`server/Lucky5.sln`](server/Lucky5.sln)
- Custom test runner via [`dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj`](server/tests/Lucky5.Tests/Lucky5.Tests.csproj)

### Required regression coverage

1. Double-up start, guess, take-half, switch, cashout, and machine-close flows
2. Frontend double-up fixed-page rendering state
3. Redis cache invalidation on every mutation that changes machine state or round state
4. RTP simulation comparison before and after tuning
5. Jackpot display updates after draw and settlement

## Merge and Parallelization Strategy

### Recommended implementation order

1. Workstream B defines any DTO changes first
2. Workstream A implements cabinet and double-up rendering against those contracts
3. Workstream C adds cache layer after B’s mutation points are known
4. Workstream D tunes RTP separately because it mainly touches CleanRoom
5. Workstream E lands regression coverage before final merge

### Recommended branch strategy

- `feature/vnext-cabinet-ui`
- `feature/vnext-doubleup-contracts`
- `feature/vnext-redis-hotcache`
- `feature/vnext-rtp-smoothing`
- `feature/vnext-regressions`

### Shared-file warning list

These files are high-conflict and must have one owner at a time:

- [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx)
- [`src/web/app/globals.css`](src/web/app/globals.css)
- [`server/src/Lucky5.Infrastructure/Services/GameService.cs`](server/src/Lucky5.Infrastructure/Services/GameService.cs)
- [`server/src/Lucky5.Application/Dtos/DoubleUpResultDto.cs`](server/src/Lucky5.Application/Dtos/DoubleUpResultDto.cs)
- [`server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs`](server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs)

## Potential Risks and Gotchas

1. **Single-component frontend congestion**
   - [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx) is large and likely to create merge conflicts
   - Mitigation: refactor structure first, then apply visual changes

2. **Legacy cabinet behavior may not fully match the current Next.js cabinet**
   - [`server/src/Lucky5.Api/wwwroot/js/game.js`](server/src/Lucky5.Api/wwwroot/js/game.js) is a reference, not the active target
   - Mitigation: use it as behavior evidence, not as a direct port mandate

3. **Redis misuse risk**
   - Current Redis usage is snapshot persistence, not request caching
   - Mitigation: add a dedicated cache abstraction instead of piggybacking on the snapshot writer

4. **RTP tuning can appear improved in one sample band and regress in another**
   - Mitigation: compare short, medium, and long simulations, not only one run

5. **Presentation-noise cleanup can accidentally remove all suspense**
   - Mitigation: preserve timing and flip cadence if desired, but never show false resolved cards

## Rollback Plan

1. Revert frontend cabinet changes independently from backend behavior changes
2. Gate Redis hot caching behind configuration so the app can fall back to current behavior
3. Keep RTP tuning isolated to [`server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs`](server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs) and [`server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs`](server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs) so it can be rolled back cleanly
4. Keep DTO changes minimal and additive where possible to reduce revert cost

## Definition of Done

The major upgrade is complete only when all of the following are true:

- Web cabinet is visually much closer to APK evidence from [`screenshots/`](screenshots)
- Double-up shows fixed 5-card pages and no moving screen behavior
- Double-up reveal uses only authoritative server outcome cards
- Redis is actively helping machine state and active-round read performance, not just snapshot persistence
- RTP remains near 85 percent but early volatility is noticeably reduced
- Regression tests and targeted verification pass

