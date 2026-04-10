# Lucky5 Clone-Parity Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update the existing vNext cabinet bundle behind a toggleable adapter flag, extend backend payloads with authoritative machine identity, and harden non-critical persistence snapshots with no invented folders.

**Architecture:** The frontend keeps `game.js` as the SignalR loop authority while the vNext `cabinet-*` scripts and styles (already in `wwwroot/js` and `wwwroot/css`) receive choreography upgrades and a feature flag guard. The backend exposes stable machine metadata by storing serial/serie/kent on `MachineLedgerState` (seeded from the canonical `Machine` entity) and continues to drive persistence through `IPersistentStateStore` snapshots.

**Tech Stack:** .NET 8 (Lucky5.Api/Domain/Infrastructure), SignalR, Redis-backed persistence, Vanilla JavaScript, CSS Grid.

---

### Task 1: [Infrastructure] Toggle and Asset Refresh

**Files:**
- Modify: `server/src/Lucky5.Api/wwwroot/js/game-config.js`
- Refresh: `server/src/Lucky5.Api/wwwroot/js/cabinet-stage-vnext.js`
- Refresh: `server/src/Lucky5.Api/wwwroot/js/cabinet-pace-vnext.js`
- Refresh: `server/src/Lucky5.Api/wwwroot/css/cabinet-layout-vnext.css`
- Refresh: `server/src/Lucky5.Api/wwwroot/css/cabinet-labels-vnext.css`
- Verify: `server/src/Lucky5.Api/wwwroot/index.html`

- [ ] **Step 1: Add the adapter feature flag**
  Insert a `features` block in `GAME_CONFIG` so the frontend can toggle adapter-level overrides.

  ```javascript
  // server/src/Lucky5.Api/wwwroot/js/game-config.js
  features: Object.freeze({
      adapterVNext: false, // flip manually to enable the clone-parity bundle
  }),
  ```

- [ ] **Step 2: Refresh the vNext asset bundle from `plans/patch/`**
  Overwrite the existing stylistic and pacing artifacts with the clone-polish versions instead of copying into a new adapter directory.

  ```powershell
  Copy-Item "plans/patch/cabinet-stage-vnext.js" "server/src/Lucky5.Api/wwwroot/js/cabinet-stage-vnext.js" -Force
  Copy-Item "plans/patch/cabinet-pace-vnext.js" "server/src/Lucky5.Api/wwwroot/js/cabinet-pace-vnext.js" -Force
  Copy-Item "plans/patch/cabinet-layout-vnext.css" "server/src/Lucky5.Api/wwwroot/css/cabinet-layout-vnext.css" -Force
  Copy-Item "plans/patch/cabinet-labels-vnext.css" "server/src/Lucky5.Api/wwwroot/css/cabinet-labels-vnext.css" -Force
  ```

- [ ] **Step 3: Confirm `index.html` still references the refreshed assets**
  The existing `<link>`/`<script>` tags already point to these CSS/JS files; ensure the ordering keeps `game-config.js` before `game.js` and the vNext scripts after `game.js` so overrides apply only when the flag is enabled.

  ```html
  <!-- server/src/Lucky5.Api/wwwroot/index.html -->
  <script src="/js/game-config.js?v=3"></script>
  <script src="/js/game.js?v=20"></script>
  <script src="/js/cabinet-stage-vnext.js?v=2"></script>
  <script src="/js/cabinet-pace-vnext.js?v=1"></script>
  ```

- [ ] **Step 4: Commit the toggle and refreshed assets**

  ```bash
  git add server/src/Lucky5.Api/wwwroot/js/game-config.js server/src/Lucky5.Api/wwwroot/js/cabinet-stage-vnext.js server/src/Lucky5.Api/wwwroot/js/cabinet-pace-vnext.js server/src/Lucky5.Api/wwwroot/css/cabinet-layout-vnext.css server/src/Lucky5.Api/wwwroot/css/cabinet-labels-vnext.css
  git commit -m "feat: add adapter feature flag and refresh vNext assets"
  ```

---

### Task 2: [Backend] Machine Identity Discovery & Mapping

**Files:**
- Modify: `server/src/Lucky5.Application/Dtos/JackpotInfoDto.cs`
- Modify: `server/src/Lucky5.Infrastructure/Services/GameService.cs`
- Modify: `server/src/Lucky5.Domain/Entities/MachineLedgerState.cs`
- Modify: `server/src/Lucky5.Domain/Entities/Machine.cs`

- [ ] **Step 1: Extend `JackpotInfoDto`**
  Add the three machine metadata properties so the API returns them to the frontend.

  ```csharp
  public sealed record JackpotInfoDto(
      decimal FullHouse,
      int FullHouseRank,
      decimal FourOfAKindA,
      decimal FourOfAKindB,
      int ActiveFourOfAKindSlot,
      decimal StraightFlush,
      string MachineSerial = "",
      int MachineSerie = 0,
      int MachineKent = 0);
  ```

- [ ] **Step 2: Discover the authoritative source for serial/serie/kent**
  Search the domain and schema to ensure these values already exist; if not, agree on a source before populating defaults.

  ```powershell
  rg -n "MachineSerial|MachineSerie|MachineKent" server/src
  rg -n "MachineSerial|MachineSerie|MachineKent" server/sql
  ```

  If the search returns nothing, plan a short discovery conversation with the data owner or schema steward, then insert the fields into `Machine`/`MachineLedgerState` so future snapshots can be seeded from the authoritative record rather than invented placeholders.

- [ ] **Step 3: Extend `Machine` and `MachineLedgerState` to carry the metadata**
  Add the new properties that mirror the business identifiers and ensure a newly created ledger copies them from the `Machine` entity.

  ```csharp
  // server/src/Lucky5.Domain/Entities/Machine.cs
  public string MachineSerial { get; init; } = string.Empty;
  public int MachineSerie { get; init; }
  public int MachineKent { get; init; }
  ```

  ```csharp
  // server/src/Lucky5.Domain/Entities/MachineLedgerState.cs
  public string MachineSerial { get; set; } = string.Empty;
  public int MachineSerie { get; set; }
  public int MachineKent { get; set; }
  ```

  Update `RequireMachineLedgerAsync` so when a ledger is initialized it captures these values from the trusted `Machine` entity instead of defaulting to derived placeholders.

- [ ] **Step 4: Surface metadata in `SnapshotJackpots`**
  Map the ledger fields into the DTO.

  ```csharp
  private static JackpotInfoDto SnapshotJackpots(MachineLedgerState ledger) =>
      new(
          ledger.JackpotFullHouse,
          ledger.JackpotFullHouseRank,
          ledger.JackpotFourOfAKindA,
          ledger.JackpotFourOfAKindB,
          ledger.ActiveFourOfAKindSlot,
          ledger.JackpotStraightFlush,
          ledger.MachineSerial,
          ledger.MachineSerie,
          ledger.MachineKent);
  ```

- [ ] **Step 5: Build to verify**
  ```bash
  dotnet build server/Lucky5.sln
  ```

- [ ] **Step 6: Commit the DTO, ledger, and entity updates**
  ```bash
  git add server/src/Lucky5.Application/Dtos/JackpotInfoDto.cs server/src/Lucky5.Infrastructure/Services/GameService.cs server/src/Lucky5.Domain/Entities/MachineLedgerState.cs server/src/Lucky5.Domain/Entities/Machine.cs
  git commit -m "feat: expose authoritative machine identity in jackpot DTO"
  ```

---

### Task 3: [Frontend] Adapter Activation and Visual Polishing

**Files:**
- Modify: `server/src/Lucky5.Api/wwwroot/js/game.js`
- Modify: `server/src/Lucky5.Api/wwwroot/js/cabinet-stage-vnext.js`
- Modify: `server/src/Lucky5.Api/wwwroot/js/cabinet-pace-vnext.js`

- [ ] **Step 1: Guard rendering with the feature flag in `game.js`**
  Enable zoning overrides only when `GAME_CONFIG.features.adapterVNext` is true.

  ```javascript
  if (GAME_CONFIG.features.adapterVNext) {
      document.body.classList.add('adapter-vnext');
      applyCloneParityLayout();
  }

  function applyCloneParityLayout() {
      const { width, height } = GAME_CONFIG.cabinet.layout;
      const container = document.getElementById('game-container');
      container.style.width = `${width}px`;
      container.style.height = `${height}px`;
  }
  ```

- [ ] **Step 2: Update `cabinet-stage-vnext.js` for face-up deals and draw replacements**
  Reuse the cloned bundle to ensure cards animate face-up with the adaptor pacing; patch the deal/draw hooks so the layout keeps the face-up order.

  ```javascript
  function animateDeal(cards) {
      const board = document.getElementById('card-area');
      board.innerHTML = '';
      cards.forEach((card, idx) => {
          const el = createCard(card);
          el.classList.add('card-deal');
          el.style.animationDelay = `${idx * 70}ms`;
          board.appendChild(el);
      });
  }
  ```

- [ ] **Step 3: Tune pacing in `cabinet-pace-vnext.js`**
  Align draw timing with the clone by staggering reveal delays and draw animations inside `game.js` when the adapter flag is enabled.

  ```javascript
  function scheduleDrawAnimation(heldMask, newCards) {
      newCards.forEach((card, idx) => {
          if (!heldMask[idx]) {
              setTimeout(() => replaceCard(idx, card), GAME_CONFIG.timing.dealStaggerMs * idx);
          }
      });
  }
  ```

- [ ] **Step 4: Commit frontend parity work**
  ```bash
  git add server/src/Lucky5.Api/wwwroot/js/game.js server/src/Lucky5.Api/wwwroot/js/cabinet-stage-vnext.js server/src/Lucky5.Api/wwwroot/js/cabinet-pace-vnext.js
  git commit -m "feat: add adapter activation hooks and clone-parity deal pacing"
  ```

---

### Task 4: [Infrastructure] Persistence Hardening

**Files:**
- Modify: `server/src/Lucky5.Infrastructure/Persistence/IPersistentStateStore.cs`
- Modify: `server/src/Lucky5.Infrastructure/Persistence/PersistentStateCheckpointService.cs`
- Modify: `server/src/Lucky5.Infrastructure/Persistence/RedisPersistentStateStore.cs`

- [ ] **Step 1: Wire IPersistentStateStore to snapshots of non-critical metadata**
  The interface should persist the latest `MachineSessionState` summary plus audit data.

  ```csharp
  public interface IPersistentStateStore
  {
      Task SaveAsync(PersistentStateSnapshot snapshot, CancellationToken cancellationToken);
      Task<PersistentStateSnapshot?> LoadAsync(CancellationToken cancellationToken);
  }
  ```

- [ ] **Step 2: Configure `PersistentStateCheckpointService` to run every 10 seconds**
  Ensure the timer saves snapshots without blocking gameplay.

  ```csharp
  // server/src/Lucky5.Infrastructure/Persistence/PersistentStateCheckpointService.cs
  var checkpointInterval = TimeSpan.FromSeconds(10);
  using var timer = new PeriodicTimer(checkpointInterval);
  while (await timer.WaitForNextTickAsync(stoppingToken))
  {
      var snapshot = await coordinator.CaptureSnapshotAsync(stoppingToken);
      await store.SaveAsync(snapshot, stoppingToken);
  }
  ```

- [ ] **Step 3: Persist snapshots safely in Redis**
  Serialize the snapshot and honor the configured key.

  ```csharp
  public async Task SaveAsync(PersistentStateSnapshot snapshot, CancellationToken cancellationToken)
  {
      var payload = JsonSerializer.Serialize(snapshot, jsonOptions);
      await cache.SetStringAsync(options.Value.SnapshotKey, payload, cancellationToken);
  }
  ```

- [ ] **Step 4: Commit persistence upgrades**
  ```bash
  git add server/src/Lucky5.Infrastructure/Persistence/IPersistentStateStore.cs server/src/Lucky5.Infrastructure/Persistence/PersistentStateCheckpointService.cs server/src/Lucky5.Infrastructure/Persistence/RedisPersistentStateStore.cs
  git commit -m "feat: harden non-critical persistence snapshots"
  ```

---

### Task 5: [QA] Verification, Parity Gate, and Rollout Readiness

- [ ] **Step 1: Backend builds and tests**
  ```bash
  dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj
  ```
  Expectation: All tests pass, confirming the contract and persistence changes compile.

- [ ] **Step 2: Manual 720x1280 parity check**
  1. Open Chrome, resize to `720x1280`, and load `/`.
  2. Flip `GAME_CONFIG.features.adapterVNext` to `true` and refresh.
  3. Verify face-up deal animations, draw pacing, and Idle/Double-Up sequences match the clone reference.
  4. Toggle the flag back to `false` to ensure no regressions appear in the legacy flow.

- [ ] **Step 3: Monitor performance for no-regression gate**
  Record heap/CPU during several rounds while persistence snapshots run to confirm the 10-second timer does not spike latency.

- [ ] **Step 4: Commit verification notes**
  ```bash
  git commit -am "test: verify clone-parity adapter and persistence gate"
  ```

---
**Plan complete and saved to `docs/superpowers/plans/2026-04-10-lucky5-clone-parity-vertical-slice-implementation-plan.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
