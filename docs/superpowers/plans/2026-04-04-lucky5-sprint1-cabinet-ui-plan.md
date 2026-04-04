# Lucky5 Sprint 1 Cabinet UI Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the active web cabinet to a more APK-faithful visual layout, with a stronger jackpot strip and more cabinet-like lower controls, without changing gameplay behavior.

**Architecture:** Keep the implementation confined to [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx) and [`src/web/app/globals.css`](src/web/app/globals.css). Use light JSX regrouping to create clearer cabinet zones, then rebuild the cabinet styling so the jackpot strip reads as a first-class visual element and telemetry becomes secondary.

**Tech Stack:** React client component, Next-style app CSS, existing Lucky5 cabinet state/handlers, manual visual verification.

---

## File Map

- **Modify:** [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx)
  - Regroup existing JSX into clearer cabinet zones
  - Add cabinet-specific wrappers and labels for jackpot strip, stage, control deck, and telemetry placement
  - Preserve all existing handlers and state wiring

- **Modify:** [`src/web/app/globals.css`](src/web/app/globals.css)
  - Add cabinet-specific styling for APK-like screen framing, jackpot strip, cabinet base, and control buttons
  - Reduce telemetry visual weight
  - Preserve responsive behavior

- **Reference only:** [`screenshots/Screenshot 2026-03-11 014751.png`](screenshots/Screenshot%202026-03-11%20014751.png)
  - Visual target for jackpot strip prominence and lower cabinet hierarchy

- **Reference only:** [`server/src/Lucky5.Api/wwwroot/js/game.js`](server/src/Lucky5.Api/wwwroot/js/game.js)
  - Legacy cabinet hierarchy cues only, not implementation source

## Constraints

- Do **not** change API calls, button semantics, machine-state logic, or double-up flow logic.
- Do **not** add new files for this sprint.
- Do **not** extract major subcomponents.
- Do **not** modify CleanRoom, backend, Redis, RTP, or tests in this sprint.

## Task 1: Baseline cabinet regrouping in [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx)

**Files:**
- Modify: [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx)

- [ ] **Step 1: Add a failing structural assertion comment block in the component region you will reshape**

Insert a temporary planning marker above the main return tree so the edit boundary is obvious while working:

```tsx
  // Sprint 1 cabinet regrouping:
  // - paytable / ledger header
  // - card stage
  // - jackpot strip
  // - lower control deck
  // - telemetry as secondary side content
```

- [ ] **Step 2: Run a quick diff check before editing**

Run:

```powershell
git diff -- src/web/components/lucky5-cabinet.tsx
```

Expected: no unexpected in-progress edits in [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx).

- [ ] **Step 3: Regroup the stage and control markup without changing handlers**

Reshape the central cabinet area so the stage contains a dedicated jackpot strip between the card stage and the control deck.

Target structure:

```tsx
          <div className="screen-body">
            <div className="playfield-stack">
              <div className="message-box">...</div>

              <div className="card-stage">
                <div className="deal-banner">...</div>
                <div className="card-row">...</div>
              </div>

              <div className="jackpot-strip" aria-label="Live jackpot strip">
                <div className="jackpot-strip-header">
                  <span className="label-kicker">Live jackpots</span>
                  <strong>APK-style meter band</strong>
                </div>
                <div className="jackpot-strip-grid">
                  <div className="jackpot-meter jackpot-meter-side">
                    <span>4K A</span>
                    <strong>{machineState ? formatMoney(machineState.jackpots.fourOfAKindA) : "--"}</strong>
                  </div>
                  <div className="jackpot-meter jackpot-meter-main">
                    <span>Full house</span>
                    <strong>{machineState ? formatMoney(machineState.jackpots.fullHouse) : "--"}</strong>
                  </div>
                  <div className="jackpot-meter jackpot-meter-center">
                    <span>Straight flush</span>
                    <strong>{machineState ? formatMoney(machineState.jackpots.straightFlush) : "--"}</strong>
                  </div>
                  <div className="jackpot-meter jackpot-meter-side">
                    <span>4K B</span>
                    <strong>{machineState ? formatMoney(machineState.jackpots.fourOfAKindB) : "--"}</strong>
                  </div>
                </div>
              </div>

              <div className="control-deck">...</div>
            </div>
          </div>
```

Notes:
- Keep existing handler calls exactly as they are.
- Reuse existing state values; only add wrapper elements and visual groupings.
- Move the jackpot presentation out of the telemetry panel so it becomes visually primary.

- [ ] **Step 4: Keep telemetry present but explicitly secondary**

Update the side column section titles and grouping so telemetry focuses on operational data instead of jackpot prominence.

Use this shape:

```tsx
        <section className="diagnostics diagnostics-secondary">
          <div className="section-title">Machine telemetry</div>
          <div className="section-subtitle">Operational backend state, kept secondary to the cabinet playfield.</div>
          <div className="diagnostic-grid">
            ...existing RTP / phase / active round / streak cards...
          </div>
        </section>
```

- [ ] **Step 5: Run a focused self-review on handler preservation**

Run:

```powershell
Select-String -Path .\src\web\components\lucky5-cabinet.tsx -Pattern "handleDealOrDraw|handleStartDoubleUp|handleTakeHalf|handleCashout|handleGuess|handleSwitch|toggleHold"
```

Expected: all original event handlers still exist and remain wired from JSX.

- [ ] **Step 6: Commit the structural regrouping**

```bash
git add src/web/components/lucky5-cabinet.tsx
git commit -m "feat: regroup lucky5 cabinet playfield layout"
```

## Task 2: Rebuild cabinet styling in [`src/web/app/globals.css`](src/web/app/globals.css)

**Files:**
- Modify: [`src/web/app/globals.css`](src/web/app/globals.css)

- [ ] **Step 1: Add failing visual checkpoints as CSS comments near the cabinet section**

Insert this comment above the cabinet layout rules:

```css
/* Sprint 1 visual checkpoints:
   - jackpot strip visually stronger than telemetry
   - lower control deck reads like cabinet hardware
   - darker playfield, tighter APK-inspired hierarchy
*/
```

- [ ] **Step 2: Strengthen the cabinet shell and screen hierarchy**

Update the cabinet shell, cabinet body, and screen rules so the screen feels more like a black playfield mounted in a wooden cabinet.

Use this direction:

```css
.cabinet-shell {
  width: min(1040px, 100%);
  grid-template-columns: minmax(0, 700px) minmax(180px, 260px);
  gap: 18px;
}

.cabinet {
  padding: 18px 18px 22px;
  background: linear-gradient(180deg, #9b531f 0%, #5c2a0e 24%, #241209 100%);
}

.screen {
  min-height: 820px;
  gap: 12px;
  padding: 14px;
  background:
    linear-gradient(180deg, rgba(11, 11, 11, 0.98), rgba(3, 3, 3, 0.995)),
    radial-gradient(circle at top, rgba(255, 176, 42, 0.08), transparent 34%);
}

.screen-body,
.playfield-stack {
  display: grid;
  gap: 12px;
}
```

- [ ] **Step 3: Add the prominent jackpot strip styling**

Create a new jackpot strip treatment that is brighter and more central than telemetry.

Add rules like:

```css
.jackpot-strip {
  display: grid;
  gap: 10px;
  padding: 12px 14px;
  border-radius: 14px;
  background: linear-gradient(180deg, rgba(20, 10, 5, 0.96), rgba(48, 18, 7, 0.96));
  border: 1px solid rgba(255, 185, 69, 0.3);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.08),
    0 8px 22px rgba(0, 0, 0, 0.35);
}

.jackpot-strip-grid {
  display: grid;
  grid-template-columns: 0.9fr 1fr 1fr 0.9fr;
  gap: 8px;
}

.jackpot-meter {
  display: grid;
  gap: 6px;
  padding: 10px 8px;
  border-radius: 12px;
  text-align: center;
  background: rgba(255, 255, 255, 0.04);
}

.jackpot-meter span {
  font-size: 0.58rem;
  text-transform: uppercase;
  color: #f1c67d;
}

.jackpot-meter strong {
  font-family: var(--display-font);
  font-size: 0.92rem;
}

.jackpot-meter-main strong {
  color: #9ce6ff;
}

.jackpot-meter-center strong {
  color: #ff6655;
}

.jackpot-meter-side strong {
  color: #84ff55;
}
```

- [ ] **Step 4: Make the lower control deck feel more like physical cabinet hardware**

Update hold buttons and action buttons so the deck feels heavier and more APK-like.

Use this direction:

```css
.control-deck {
  margin-top: 6px;
  padding: 18px 18px 20px;
  border-radius: 20px 20px 28px 28px;
  background:
    linear-gradient(180deg, rgba(120, 52, 14, 0.96), rgba(64, 24, 8, 0.98)),
    linear-gradient(90deg, rgba(255, 211, 90, 0.06), transparent);
}

.hold-button,
.action-button,
.guess-button {
  min-height: 74px;
  border-radius: 16px;
  font-size: 0.7rem;
  letter-spacing: 0.03em;
}

.hold-button {
  background: linear-gradient(180deg, #ffd64d 0%, #c78200 100%);
  color: #332003;
}

.action-button.main {
  background: linear-gradient(180deg, #ff5d42 0%, #b41e10 100%);
}

.action-button.warning,
.guess-button.big {
  background: linear-gradient(180deg, #ffbf3b 0%, #c26b00 100%);
  color: #2c1904;
}

.action-button.success,
.guess-button.small {
  background: linear-gradient(180deg, #53e8ff 0%, #1171ac 100%);
}

.action-button.ghost {
  background: linear-gradient(180deg, #f7edd6 0%, #bca57a 100%);
  color: #28190d;
}
```

If the white-style ghost button makes `TAKE SCORE` look too neutral, keep `TAKE SCORE` on a dedicated warm gold style and use the lighter ghost style only for lower-priority controls.

- [ ] **Step 5: Demote telemetry styling**

Adjust the side-column diagnostics so they read as support panels, not primary playfield UI.

Add or revise rules like:

```css
.side-column {
  gap: 12px;
}

.diagnostics-secondary {
  opacity: 0.82;
  background: rgba(20, 18, 14, 0.82);
}

.diagnostic-card {
  padding: 10px;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.035);
  border: 1px solid rgba(255, 212, 71, 0.08);
}
```

- [ ] **Step 6: Keep the layout responsive**

Update the mobile breakpoint so the jackpot strip and control deck still stack cleanly.

Use rules like:

```css
@media (max-width: 820px) {
  .cabinet-shell {
    grid-template-columns: 1fr;
  }

  .jackpot-strip-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 560px) {
  .jackpot-strip-grid,
  .hold-row,
  .card-row {
    grid-template-columns: 1fr;
  }
}
```

- [ ] **Step 7: Commit the cabinet styling pass**

```bash
git add src/web/app/globals.css
git commit -m "feat: restyle lucky5 cabinet for apk parity"
```

## Task 3: Integrate JSX wrappers with the new CSS vocabulary

**Files:**
- Modify: [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx)
- Modify: [`src/web/app/globals.css`](src/web/app/globals.css)

- [ ] **Step 1: Apply new wrapper classes in the component**

Update the component so the CSS classes introduced in Task 2 are actually used.

Required classes to appear in JSX:

```tsx
<div className="screen-body">
<div className="playfield-stack">
<div className="jackpot-strip">
<div className="jackpot-strip-header">
<div className="jackpot-strip-grid">
<div className="jackpot-meter jackpot-meter-side">
<div className="jackpot-meter jackpot-meter-main">
<div className="jackpot-meter jackpot-meter-center">
<section className="diagnostics diagnostics-secondary">
```

- [ ] **Step 2: Run a focused selector presence check**

Run:

```powershell
Select-String -Path .\src\web\components\lucky5-cabinet.tsx -Pattern "jackpot-strip|jackpot-meter|diagnostics-secondary|screen-body|playfield-stack"
Select-String -Path .\src\web\app\globals.css -Pattern "jackpot-strip|jackpot-meter|diagnostics-secondary|screen-body|playfield-stack"
```

Expected: all new JSX classes also have matching CSS rules.

- [ ] **Step 3: Commit integration cleanup**

```bash
git add src/web/components/lucky5-cabinet.tsx src/web/app/globals.css
git commit -m "feat: wire sprint1 cabinet visual zones"
```

## Task 4: Verification and regression check

**Files:**
- Verify: [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx)
- Verify: [`src/web/app/globals.css`](src/web/app/globals.css)

- [ ] **Step 1: Run a clean diff review**

Run:

```powershell
git diff -- src/web/components/lucky5-cabinet.tsx src/web/app/globals.css
```

Expected: only cabinet regrouping and visual styling changes, no API or logic edits.

- [ ] **Step 2: Confirm no new API calls or gameplay mutations were introduced**

Run:

```powershell
Select-String -Path .\src\web\components\lucky5-cabinet.tsx -Pattern "fetch\(|await .*\(|startDoubleUp\(|guessDoubleUp\(|switchDealer\(|takeHalf\(|cashoutDoubleUp\(" 
```

Expected: only the existing handler call sites remain; no extra behavior-specific async flows were added for Sprint 1.

- [ ] **Step 3: Manual visual review against the APK screenshot**

Checklist:

```text
1. The jackpot strip is visually stronger than the telemetry panel.
2. The lower control deck reads like cabinet hardware, not dashboard controls.
3. The black playfield remains the visual center above the control deck.
4. Telemetry looks secondary and does not compete with the jackpot strip.
5. Existing control labels remain recognizable and wired.
```

- [ ] **Step 4: Final commit for the sprint slice if needed**

```bash
git add src/web/components/lucky5-cabinet.tsx src/web/app/globals.css
git commit -m "feat: complete sprint1 lucky5 cabinet ui parity pass"
```

## Spec Coverage Check

- **Light JSX regrouping only**: covered in Task 1 and Task 3
- **Prominent APK-like jackpot strip**: covered in Task 1 Step 3 and Task 2 Step 3
- **Cabinet-style lower control deck**: covered in Task 2 Step 4
- **Telemetry secondary**: covered in Task 1 Step 4 and Task 2 Step 5
- **No gameplay/API/Redis/RTP changes**: enforced in constraints and verification Task 4

## Placeholder Scan

No `TODO`, `TBD`, or deferred implementation markers remain in this plan.

## Type Consistency Check

- Uses only existing React state and handler names from [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx)
- Introduces only CSS wrapper classes, not new data contracts
- Jackpot values referenced are consistent with current `machineState.jackpots` usage in [`src/web/components/lucky5-cabinet.tsx`](src/web/components/lucky5-cabinet.tsx)

