# Lucky 5 v8 — Handoff (read this first)

**Last updated:** 2026-04-20
**Status at handoff:** Code shipped to `main` branch (local). Pending Cloud Run / Azure redeploy + user-run verification.

This is the **shortest path** to resuming Lucky 5 v8 work. If you only have five
minutes, read this file. Deeper context lives in `LUCKY5_V8_PLAN.md` and
`CONTINUATION_GUIDE.md`.

---

## 1. What v8 is

Major version focused on two tracks:

| Track | Goal | Rule changes allowed? |
|-------|------|-----------------------|
| **A — Engine RTP** | Calibrate composite RTP to ~80% long-term under existing rules. | **No.** Only `EngineConfig` knobs change. |
| **B — Cabinet realism** | Make the web cabinet look & feel like a real Lebanese arcade. | Frontend only. |
| **C — v8 surgery (2026-04-20)** | Fix hold-badge, FH target, 4OAK star accrual, paytable drain, layout. | Targeted fixes. |

---

## 2. Current state

### What is done ✅

- **Track A (RTP):** `EngineConfig` recalibrated in `server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs`
  (see `LUCKY5_V8_PLAN.md` Track A for the knob table). Rules unchanged.
- **Track B (visuals):** Three additive layers wired into `index.html`:
  - `server/src/Lucky5.Api/wwwroot/css/cabinet-v8-realism.css` — wooden bezel, CRT scanlines, LED heartbeat, cabinet shake on big wins, idle attract sweep, reduced-motion fallback.
  - `server/src/Lucky5.Api/wwwroot/css/cabinet-v8-quality.css` — pure-CSS buttons (no PNG dependency), `cqh`-based paytable/card sizing, hold-badge visibility fix, `.fh-target` style, star styling.
  - `server/src/Lucky5.Api/wwwroot/js/cabinet-v8-effects.js` — marquee, coin shower, win-tier observer, idle attract, button haptics, card-face load-error diagnostic (adds `.v8-face-error` red MISSING ribbon on 404).
- **Track C (2026-04-20 surgery):**
  - Hold sign shows correctly (selector was wrong — fixed to `.card-slot.held`).
  - First HOLD button paints red-orange "FH" when armable, so FH-rank cycling vs hold toggling is visually distinct.
  - Full House jackpot meter moved to bottom-right of paytable (out of the row flow → no more overflow glitches).
  - Duplicate `#win-amount-display` hidden — winnings drain from the matching jackpot counter straight into `#credits` via the existing `animateJackpotFill`.
  - `ApplyJackpotContributions` (both `GameService.cs` and `Simulation/Program.cs`) now increments **only the starred 4OAK jackpot** — the non-starred side is frozen for the round.
  - Red star on active 4OAK counter is bright red, blinking, with ring on the active counter.
- **Assets:** 178 card/button/font/board/logo/coin files restored from commit `933788b^`. `Microsoft.NET.Sdk.Web` auto-publishes `wwwroot/`, so Cloud Run / Azure images include them.

### What is pending ⏳

| # | Task | Who runs it | How |
|---|------|-------------|-----|
| P1 | **Regression tests** | user (local SDK issue on agent machine) | `dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj` |
| P2 | **RTP smoke sim (200k rounds)** | user | `dotnet run --project server/src/Lucky5.Simulation/Lucky5.Simulation.csproj -c Release -- --rounds 200000` |
| P3 | **RTP certification sim (500k rounds)** | user | `dotnet run --project server/src/Lucky5.Simulation/Lucky5.Simulation.csproj -c Release -- --certification` |
| P4 | **Commit + redeploy** | user | `git push origin main` → Cloud Run / Azure auto-deploy |
| P5 | **Hard refresh browser** | user | `Ctrl+Shift+R` to bypass stale CSS/JS cache |
| P6 | **Visual verification** | user | See checklist below |

### Known issues & follow-ups 🔧

- **Round has TWO bets, so TWO jackpot contributions per round** — not a bug. `GameService.BeginRoundAsync`
  debits the bet and contributes once at deal; `DrawAsync` debits the bet again and contributes once at draw.
  Both contributions honor the same deal-time starred slot (via `round.ActiveFourOfAKindSlotAtDeal`). The sim
  at `server/src/Lucky5.Simulation/Program.cs:120,125` mirrors this deliberately. **Do not remove the second call.**
- **Root `CLAUDE.md` is bloated** (~340 KB, stuffed with unrelated API boilerplate). Per `AGENTS.md` policy,
  don't paste docs into it. Future cleanup welcome.
- **Data Connect schema** (`dataconnect/schema/schema.gql`) is aspirational; runtime is still `InMemoryDataStore`.
  Month-scale durability requires migrating `MachineLedgerState`, `MachineSessionState`, and `Agent` to Postgres.
- **Local SDK issue on Windows**: `error MSB4019` when invoking `dotnet` — the agent couldn't run tests locally.
  User's machine is fine. Cloud Run / Azure builders are the source of truth for successful builds.
- **Build-breaks from private-helper signature changes** — if you alter `ApplyJackpotContributions` or similar
  helpers, `grep` for all call sites first. The 2026-04-20 first push missed `GameService.cs:301` (draw-phase
  call) and Cloud Run rejected the build with `CS7036`. Fix landed in the follow-up commit.

---

## 3. File map (what to touch when)

### Backend — authoritative game logic

| File | When to edit |
|------|--------------|
| `server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs` | RTP calibration knobs. Rule shape. |
| `server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs` | RTP controller, distribution modes. |
| `server/src/Lucky5.Domain/Game/CleanRoom/Lucky5DoubleUpEngine.cs` | Double-up rules. |
| `server/src/Lucky5.Infrastructure/Services/GameService.cs` | Deal/draw/close flow, jackpot accrual & routing. |
| `server/src/Lucky5.Infrastructure/Services/AdminService.cs` | Admin resets. |
| `server/tests/Lucky5.Tests/` | Regression. Run via `dotnet run --project …` (never `dotnet test`). |

### Frontend — vanilla JS cabinet (the playable target)

| File | When to edit |
|------|--------------|
| `server/src/Lucky5.Api/wwwroot/index.html` | DOM structure, script/style `?v=` cache busters. |
| `server/src/Lucky5.Api/wwwroot/js/game.js` | Game state machine, API calls, round lifecycle. |
| `server/src/Lucky5.Api/wwwroot/js/cabinet-stage-vnext.js` | Card rendering, deal/draw animations, hold state. |
| `server/src/Lucky5.Api/wwwroot/js/cabinet-v8-effects.js` | v8 dynamic effects (marquee, coin shower, attract, card-face error guard). |
| `server/src/Lucky5.Api/wwwroot/css/cabinet-layout-vnext.css` | **Locked 720×1280 portrait grid.** All zones are absolute-positioned with `cqh/cqw` units via `container-type: size` on `#game-screen`. Do not use `vw/vh/px` for in-cabinet sizing. |
| `server/src/Lucky5.Api/wwwroot/css/cabinet-v8-realism.css` | Cabinet frame, CRT effects, button haptics. |
| `server/src/Lucky5.Api/wwwroot/css/cabinet-v8-quality.css` | Pure-CSS buttons, paytable sizing, hold-badge reveal, FH jackpot placement, star/active-slot styling. |
| `server/src/Lucky5.Api/wwwroot/css/game.css` | Legacy cabinet styles. Hold badge base styling here (`.card-slot.held .hold-badge { display: block }`). |

### DO-NOT-EDIT

- `sources/` — decompiled APK, reference only.
- `dataconnect/schema/schema.gql` — aspirational, not yet deployed.

---

## 4. Visual verification checklist (post-redeploy)

After `git push` + Cloud Run / Azure redeploy + `Ctrl+Shift+R`:

1. **Cards show faces after DEAL** — if any slot shows a red `MISSING` ribbon, a specific card PNG is missing from the deployed image; check console for `[Lucky5 v8] card face failed to load …`.
2. **Hold badge appears when a card is held** — yellow `HOLD` text pulses under the card face; golden ring glows around the card face.
3. **First HOLD button turns red-orange with `FH` label** after clicking BET once in idle state — pressing it cycles the Full House jackpot rank (2 → 3 → … → A → 2).
4. **Full House jackpot meter** is a gold-bordered pill at the bottom-right of the paytable — above the deck, slightly right of the 2 PAIR row.
5. **Only one of `4K-A` / `4K-B`** has the red blinking star and red-tinted ring at any time. Rotates per-round based on the seed.
6. **Winning round drain** — after a win, the matching jackpot counter (or paytable row) decrements while `#credits` increments. No duplicate "WIN 123,456" label.
7. **LUCKY 5 POKER idle title** is a reasonable size (not screen-filling), tilted, glowing cyan.
8. **Paytable** fits all 8 hand rows cleanly inside its 15% band — no white overflow ribbon at the bottom.
9. **Buttons render with pure CSS** — HOLD row yellow, action row orange/red/cream/green, circular MENU with hamburger glyph.
10. **SFX, idle attract, coin shower** all trigger on corresponding events without layout shifts.

---

## 5. How the tricky bits actually work

### Hold state sync

- **State:** `holdIndexes` (Set<number>) in `game.js`.
- **DOM class:** `.card-slot.held` — set by `toggleHold` (`game.js:874-875`), `applyHeldIndexes`, `CabinetStage.setHold`.
- **Badge:** `<div class="hold-badge">HOLD</div>` inside every slot (created by `initCardSlots`).
- **Reveal rule:** `game.css:792` and `cabinet-v8-quality.css:412` both target `.card-slot.held .hold-badge`.
- **Do NOT use** `.is-held` or `[data-held="1"]` — nothing sets them. This was the April 2026 bug.

### Full-House rank selector (first HOLD button, dual-mode)

- **Trigger condition:** `canAdjustJackpotRank()` → `gameState === 'idle' && jackpotRankArmed`.
- **Armed by:** `doBet()` sets `jackpotRankArmed = true` after any bet in idle state.
- **Disarmed by:** deal, state transitions that clear round state.
- **Click handler:** `game.js:2659-2662` — if the above holds, call `cycleJackpotRank()` which POSTs `/api/Game/…/jackpotRank` and updates `jackpotRank` (2-14 where 14 = Ace).
- **Visual:** `game.js::setButtonStates` toggles `.fh-target` on `holdBtns[0]`. `cabinet-v8-quality.css` swaps the button label from `HOLD` to `FH` and paints it red-orange pulsing.

### Two 4OAK jackpots + red star

- **State:**
  - Server: `MachineLedgerState.JackpotFourOfAKindA`, `JackpotFourOfAKindB`, `ActiveFourOfAKindSlot` (0 or 1).
  - Client: `window.active4kSlot`, mirrored from `jackpots.activeFourOfAKindSlot` on every `updateJackpotDisplay`.
- **Per-round rotation:** `active4kSlot = (ledger.RoundCount % 2 == 0) ? (int)(seed % 2) : 1 - (int)(seed % 2)` — runs at deal time in `GameService.BeginRoundAsync`. Alternates every round with seed-driven randomness, never stuck on one side.
- **Captured:** `GameRound.ActiveFourOfAKindSlotAtDeal` stores the deal-time value so mid-round ledger mutations can't redirect the payout (regression test in `GameServiceRegressionTests.cs:165-194`).
- **Accrual rule (NEW 2026-04-20):** `ApplyJackpotContributions` only increments the active slot. Non-starred side is frozen.
- **Payout rule:** `GameService.cs:363-371` checks `round.ActiveFourOfAKindSlotAtDeal` and pays A or B accordingly.
- **Star UI:** `game.js::updateActive4kHighlight` flips `starA.style.display` / `starB.style.display` between `'inline'` and `'none'`. CSS paints the visible one red, blinking, glowing.

### Winnings display (drain-from-paytable)

- **Drain animation:** `game.js::animateJackpotFill(amount, startBalance, handName)` at `1765-1815`.
- **Target counters by hand:**
  - FullHouse → `#jp-counter-fh .jp-cval`
  - FourOfAKind (active) → `#jp-counter-a .jp-cval` if slot 0 else `#jp-counter-b .jp-cval`
  - StraightFlush → `#jp-counter-center .jp-cval`
  - Other hands → pay-row highlight via `updatePaytable(currentHandRank)`.
- **Status text:** `#game-message` shows `JACKPOT TRANSFER x / total` during the ramp.
- **Hidden chrome:** `#win-amount-display` is CSS `display: none` — JS still writes to it for compatibility, but it's invisible.

### Cabinet coordinate system (DO NOT BREAK)

- `#game-screen` has `container-type: size` → descendants use `cqh` (1cqh = 1% of cabinet height) and `cqw`.
- All in-cabinet zones (`#paytable`, `#card-area`, `#controls`, etc.) are `position: absolute` with fixed `top/height` percentages relative to `#game-screen`.
- **Rules:**
  - Never use `vw/vh/px` for font-size inside the cabinet — it desyncs between portrait-letterboxed desktop and narrow mobile.
  - Never add `margin-top` / `min-height` to absolute-positioned zones — breaks the grid.
  - Never force `aspect-ratio` on flex-stretched children of zones — collapses them.
- When a layout change is needed, edit the zone definition in `cabinet-layout-vnext.css`, not sibling overrides.

---

## 6. Deploy pipeline

### Cloud Run (primary)

- **Dockerfile:** `Dockerfile` (repo root) — multi-stage SDK build + ASP.NET runtime.
- **Publish output:** `dotnet publish -c Release -o /app/publish` — auto-includes `wwwroot/**`.
- **Static serving:** `Program.cs:133-134` → `app.UseDefaultFiles(); app.UseStaticFiles();`.
- **Cache-busters:** Bump `?v=N` on the changed CSS/JS `<link>`/`<script>` in `index.html` so browsers pull fresh copies.

### Azure App Service

- **Dockerfile:** `server/Dockerfile.azure` — identical flow, Azure-tuned.

### Mobile (Flutter / Capacitor)

- Not the primary target. Web cabinet must work first.
- Flutter client in `client/` uses SignalR + REST; Firebase wired via `FirebaseService` in `client/lib/core/`.

---

## 7. Commands cheat sheet

```powershell
# Build
dotnet build server/Lucky5.sln -v minimal

# Test (NOT dotnet test — custom runner)
dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj

# RTP simulation (calibration)
dotnet run --project server/src/Lucky5.Simulation/Lucky5.Simulation.csproj -c Release -- --rounds 200000
dotnet run --project server/src/Lucky5.Simulation/Lucky5.Simulation.csproj -c Release -- --certification

# Run API locally
dotnet run --project server/src/Lucky5.Api/Lucky5.Api.csproj

# Local full stack
docker compose -f infra/docker-compose.yml up

# Smoke test
pwsh scripts/smoke-api.ps1

# Git push (triggers Cloud Run auto-deploy)
git push origin main
```

---

## 8. Contact points in code (jump here when stuck)

| Symptom | Start reading at |
|---------|------------------|
| Hold badge not showing | `cabinet-v8-quality.css:412` and `game.css:792` — both MUST target `.card-slot.held`. |
| Card slots collapsed / invisible | `cabinet-v8-quality.css:334-370` (never force `aspect-ratio`; `flex:1 1 0` + `min-height:0`). |
| Paytable overflow / glitch ribbon | `cabinet-v8-quality.css:233-269` — rows sized in `cqh`; FH meter absolute at bottom-right. |
| Star on wrong 4OAK or never switching | `GameService.cs:222`, `game.js::updateActive4kHighlight`. |
| Non-starred 4OAK still growing | `GameService.ApplyJackpotContributions` and the mirror in `Simulation/Program.cs`. |
| FH button looks identical to other holds | `game.js::setButtonStates` must toggle `.fh-target`; CSS at `cabinet-v8-quality.css:138-169`. |
| LUCKY 5 POKER huge | `cabinet-v8-quality.css:447-457` — `6cqh` not `vw`-based. |
| Cards 404 on deployed server | Console → `[Lucky5 v8] card face failed to load` from `cabinet-v8-effects.js:345-411`. Also visible as red `MISSING` ribbons. |

---

## 9. Chronological history (short)

- **v6 (Mar 2026):** Lebanese-paytable parity pass; dual-credit economy; Firebase wiring.
- **v7 (early Apr 2026):** Agent/reward systems; machine close/reset hardening; session continuity.
- **v7 RTP rebalance:** see `RTP_REBALANCING_ARCHITECTURE.md`.
- **v8 Track A (mid-Apr 2026):** RTP calibration to 80% without rule changes. See `LUCKY5_V8_PLAN.md`.
- **v8 Track B (mid-Apr 2026):** Cabinet realism layers. See `LUCKY5_V8_PLAN.md`.
- **v8 Asset restore (2026-04-19):** 178 missing PNG/TTF assets recovered from commit `933788b^`.
- **v8 CSS coordinate-system rewrite (2026-04-19):** `cabinet-v8-quality.css` migrated from `vw/vh/px` to `cqh` after user-reported layout breakage.
- **v8 Track C surgery (2026-04-20):** Hold-badge selector fix, FH-target button visual, FH meter relocation, win-amount-display hidden, single-star 4OAK accrual. **This handoff doc.**
