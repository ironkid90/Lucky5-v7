# Lucky5 Clone-Parity Major Upgrade Plan

Full phased implementation plan to bring the Lucky5 web cabinet to clone-level visual and interaction parity, based on `docs/LUCKY5_SUCCESSOR_CLONE_PARITY_PLAN_2026-04-05.md`.

---

## Current State Summary

| Area | Vanilla JS (`wwwroot/`) | React (`src/web/`) |
|------|------------------------|-------------------|
| Shell screens | auth, lobby, wallet, admin, game | auth only (inline) |
| Cabinet layout | Clone-faithful portrait stack | Dashboard/sidebar layout |
| Card rendering | PNG clone assets | CSS-only text cards |
| Control deck | Clone button images + wood deck | Generic styled buttons |
| Jackpot block | 4K A/B, SF, FH counters + rank | Simplified strip |
| Double-up | Trail cards + dealer in card stage | 2-card side panel |
| Menu overlay | Hamburger → CASH IN/OUT/LOBBY/RESET | None |
| Label system | Pixel text, color-coded, positioned | Generic status chips |
| SignalR | Connected | Not connected |
| Coordinate system | Portrait-first 540px max | Flexible desktop layout |

**Decision point**: The vanilla JS cabinet is already closer to parity. The React cabinet is a modern framework but lacks most shell and visual features. The parity plan explicitly says "Target the React web cabinet first" but the vanilla JS cabinet is the shipped playable surface.

**Recommended approach**: Apply the parity upgrade to the **vanilla JS cabinet** (the shipped surface) first, since it already has 70%+ of the shell infrastructure. Port learnings to React afterward as a separate track.

---

## Phase 0: Foundation & Asset Audit (Est. 2h)

### 0.1 — Asset inventory
- Verify all clone button images exist in `wwwroot/assets/images/` (hold_on/off, big, small, cancel_hold, deal_draw, bet, take_half, take_score, board)
- Verify all 52 card PNGs + bside.png exist in `wwwroot/assets/images/cards/`
- Verify `lucky5.png` splash/brand asset exists
- Verify `ARCADE.ttf` font is loaded and working
- Catalog any missing assets needed from the APK extraction folder

### 0.2 — Backend DTO audit
- Check if `JackpotInfoDto` already has all fields needed for `JackpotDisplayModel`:
  - ✅ `FourOfAKindA`, `FourOfAKindB`, `StraightFlush`, `FullHouse`, `FullHouseRank`, `ActiveFourOfAKindSlot`
  - ❌ Missing: `MachineSerial`, `MachineSerie`, `MachineKent` (currently client-side vars only)
- Check if `DoubleUpResultDto` supports trail cards for the legacy viewport:
  - ❌ Missing: `CardTrail` (visible trail of previous double-up results)
  - ❌ Missing: `IsLucky5Active` flag
- **Action**: Add missing display-only fields to DTOs where the backend already has the data

### 0.3 — Branch setup
- Create feature branch `feature/clone-parity-vnext` from current main
- Verify build: `dotnet build server/Lucky5.sln -v minimal`
- Verify tests: `dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj`

---

## Phase 1: Coordinate System & Cabinet Frame (Est. 4h)

**Target**: Parity plan §2 — single portrait reference board

### 1.1 — CSS coordinate system overhaul
- Refactor `game.css` game-screen layout to use a single `720×1280` reference board
- Replace flexible/flowing CSS with fixed vertical percentage stack:
  ```
  0%-15%   → paytable + credit/stake
  15%-19%  → label band (Lucky5 / contextual)
  19%-38%  → card stage
  38%-42%  → win amount row
  42%-53%  → jackpot + machine info block
  53%-67%  → HOLD lamps row
  67%-84%  → main action row
  84%-97%  → bottom row (take-half, menu, take-score)
  ```
- Keep centered single-column for all game states
- Desktop: add framing space around cabinet, cabinet face stays proportionally identical

### 1.2 — Board background
- Apply `board.png` as the control deck wood texture (currently clone asset exists)
- Set black CRT playfield above the control deck
- Maintain CRT overlay scanline effect

### 1.3 — Responsive scaling
- Scale the entire board as one unit using `aspect-ratio: 9/16` or viewport-relative sizing
- Desktop wraps the cabinet column with dark framing, never reflowing controls into sidebars

**Verification**: Screenshot at 720×1280 viewport, compare to attached reference images

---

## Phase 2: Label System & Text Hierarchy (Est. 6h)

**Target**: Parity plan §3, §4 — labels as first-class visual assets

### 2.1 — Paytable typography
- Match clone rainbow row colors exactly:
  - RF=red/white, SF=red, 4K=cyan, FH=yellow, Flush=red, Straight=green, 3K=cyan, 2P=yellow
- Add solid selection highlight box around the active jackpot hand row
- Payout values update dynamically based on current stake
- Use pixel font (`Press Start 2P` / `Arcade`) at correct scale

### 2.2 — Credit & Stake labels
- `CREDIT` label: green, value in white below
- `STAKE` label: amber/gold, value in white below
- Fixed top-right position, pixel font ~18px equivalent

### 2.3 — Machine info block labels
- `SERIE - {n}` in green
- `KENT /3 : {n}` in green
- Three jackpot counters in gold/amber: `× {4KA}` / `{SF}` / `{4KB}`
- `S/N: {serial}` in green
- `4 OF A KIND   WINS BONUS` in large white pixel text, full width
- Full House meter: black text/numbers inside white container

### 2.4 — Contextual banner labels
- `LUCKY 5 IS ACTIVE` banner between paytable and cards (already exists in vanilla, needs positioning)
- `PRESS HOLDS TO KEEP CARD` mid-prompt
- `INSERT COIN`, `PLAY 5000`, win messages in bottom info bar
- `HI LO GAMBLE`, `ACE COUNTS HI OR LO` during double-up

### 2.5 — Color preservation
- Jackpot side counters: green
- Straight-flush center counter: red
- Full-house meter: black on white container
- Machine serial and large win amount: gold with dark outline
- Persistent rule text: white or gold

**Verification**: Side-by-side comparison of label placement and colors against reference screenshots

---

## Phase 3: Card Stage & Choreography (Est. 4h)

**Target**: Parity plan §5 — fixed slots, aligned columns, animations

### 3.1 — Five-card alignment
- Fixed card slot positions (no responsive reshuffle)
- Each card column aligns vertically with:
  - One paytable reading line above
  - One HOLD lamp below
  - One control action target on deck

### 3.2 — Deal animation
- Cards enter left to right with 90–120ms stagger
- Slide from above with fast opacity recovery
- Use existing card PNG assets

### 3.3 — Draw animation
- Only unheld cards change
- Held cards remain physically stable
- Replacements use in-place flip/drop at 80–100ms

### 3.4 — Hold visuals
- Use `hold_on.png` / `hold_off.png` clone assets for hold lamps
- Active state glows brighter, does not move layout
- HOLD text label on each lamp

### 3.5 — Card art
- Keep crisp flat clone-extracted card PNGs (already in `assets/images/cards/`)
- No glossy CSS card replacements

**Verification**: Deal 5 cards, observe stagger timing; hold 2 cards, draw, confirm held cards don't move

---

## Phase 4: Control Deck Rebuild (Est. 4h)

**Target**: Parity plan §8 — physical wood-toned deck with clone assets

### 4.1 — Button image swap
- Replace CSS-styled buttons with clone button image assets:
  - `hold_on.png` / `hold_off.png` for HOLD row
  - `big.png` / `big_on.png` for BIG
  - `small.png` / `small_on.png` for SMALL
  - `cancel_hold.png` / `cancel_hold_on.png` for CANCEL HOLD
  - `deal_draw.png` / `deal_draw_on.png` for DEAL DRAW
  - `bet.png` / `bet_on.png` for BET
  - `take_half.png` / `take_half_on.png` for TAKE HALF
  - `take_score.png` / `take_score_on.png` for TAKE SCORE
- MENU: dark circular button with ☰ icon

### 4.2 — Button layout
- Top row: 5 HOLD lamps aligned to card centers
- Main action row: BIG, SMALL, CANCEL HOLD, DEAL DRAW, BET
- Bottom row: TAKE HALF, MENU, TAKE SCORE

### 4.3 — Button color semantics (verify against assets)
- HOLD, BIG, SMALL: amber
- CANCEL HOLD: cream/beige
- DEAL DRAW: **red** (Lebanese convention)
- BET: **green** (Lebanese convention)
- TAKE HALF: red
- TAKE SCORE: orange/amber
- MENU: dark circle

### 4.4 — Press feedback
- Active/pressed state uses `*_on.png` variant
- Disabled state dims the button
- Touch-friendly hit targets

**Verification**: All buttons visible, correct colors, press states work, layout matches reference images

---

## Phase 5: Win Amount Display & Jackpot Block (Est. 4h)

**Target**: Parity plan §7 — machine-info block verbatim from clone

### 5.1 — Win amount display
- Large golden number below cards with outlined/embossed styling
- Active jackpot slot indicator letter (`A` or `B`) beside the amount
- Gold color with text shadow/outline effect

### 5.2 — Machine info block structure
- Machine identity row (SERIE, KENT)
- Three jackpot counters in a line (4K A, SF, 4K B)
- Full-house rank + full-house counter row
- Machine serial row
- Bottom statement text: `4 OF A KIND WINS BONUS`

### 5.3 — Active highlight
- Active 4K slot highlight box on the jackpot counter
- Selected paytable row highlight box
- Full-house selected rank appears both on paytable row and in FH meter label

### 5.4 — Backend DTO additions (if needed)
- Add `MachineSerial`, `MachineSerie`, `MachineKent` to `MachineSessionDto` or a new display DTO
- These are display fields only — backend already tracks them as state

**Verification**: Jackpot counters update live via SignalR; active slot highlight toggles; FH rank badge correct

---

## Phase 6: Double-Up Viewport Rebuild (Est. 6h)

**Target**: Parity plan §6 — legacy clone-style trail viewport

### 6.1 — Trail card model
- Replace simplified 2-card panel with full trail viewport
- Visible page: 4 historical/dealer slots + 1 active challenger
- Challenger slot shows shuffling animation or revealed card

### 6.2 — Backend DTO addition
- Add `CardTrail` (list of previous double-up results) to `DoubleUpResultDto`
- Add `IsLucky5Active` boolean flag
- These require backend changes to track and return the trail

### 6.3 — Double-up card rendering
- All double-up cards render inside the main card stage area
- `BIG / SMALL ?` text on the shuffle slot
- `SMALL` and `BIG` labels under relevant revealed cards
- Dealer card gets gold-highlighted frame
- `5♠` gets white Lucky5 lightning flash (brief glow, not layout change)

### 6.4 — Double-up labels
- `HI LO GAMBLE` in the du-info band
- `ACE COUNTS HI OR LO` below it
- Lucky5 rule text in narrow band above bottom info bar
- `BIG`, `SMALL`, `TAKE HALF`, `TAKE SCORE` stay on main cabinet deck

### 6.5 — Shuffle animation
- Rapid random card image cycling at ~80ms during challenger shuffle
- Uses preloaded card PNG pool

**Verification**: Enter double-up, observe trail, verify shuffle animation, check 5♠ flash, confirm labels

---

## Phase 7: Menu Overlay & Shell Parity (Est. 6h)

**Target**: Parity plan §8 (menu), §9 (full app shell)

### 7.1 — Menu overlay
- Already exists in vanilla JS cabinet as `#menu-panel`
- Verify it opens as machine-mounted overlay (not full-page drawer)
- Actions: CASH IN, CASH OUT, BACK TO LOBBY, RESET MACHINE, LOGOUT, CLOSE
- Accessible in idle/win/doubleup states

### 7.2 — Shell screen router
- Verify all shell states work correctly:
  - `auth` → `lobby` → `game` (with menu access)
  - `lobby` → `wallet` → `lobby`
  - `lobby` → `admin` → `lobby` (admin role only)
- Introduce frontend-only `ShellScreen` concept: `auth | lobby | wallet | admin | game`

### 7.3 — Shell visual family
- Black play surfaces everywhere
- Warm brown cabinet materials on game screen
- Pixel text / hard-edged compact typography throughout
- Flat iconography, no generic SaaS cards
- Machine selection cards in lobby styled as cabinet-family elements

### 7.4 — Wallet shell
- Cash-in, move-win-to-wallet, cash-out, leave-machine actions
- After wallet flow, return to poker cabinet (not replace identity)
- Style consistent with cabinet aesthetic

### 7.5 — Navigation hardening
- One predictable navigation model for all menu/shell transitions
- Session state preserved across lobby/wallet/admin round-trips
- No state loss on menu open/close

**Verification**: Navigate auth→lobby→wallet→lobby→game→menu→lobby→game, confirm no state loss

---

## Phase 8: Pace & Count-Up Rules (Est. 3h)

**Target**: Parity plan §10 — tight presentation rhythm

### 8.1 — Standard collection animation
- Win credit rolls into credit counter over 1.5–5s depending on amount
- Animated rolling meter, not instant ledger update

### 8.2 — Jackpot fill animation
- 10–15s count-up for jackpot wins depending on amount

### 8.3 — Lucky5 flash
- Very short white/gold screen flash
- Followed by banner flicker and card glow
- Already partially implemented in vanilla JS (`#lucky5-flash`)

### 8.4 — No modal pauses
- No dialog boxes between result → collection → next actionable state
- Player-controlled loop but tight presentation rhythm

**Verification**: Win a hand, observe count-up timing; trigger Lucky5, observe flash; verify no modal interruptions

---

## Phase 9: Frontend Types & Display Models (Est. 2h)

**Target**: Parity plan §"Public Interfaces" section

### 9.1 — New frontend types (vanilla JS as documented objects)
- `CabinetDisplayModel` — UI-ready aggregate for one machine view
- `LabelBandState` — banner text, tone, visibility, reserved height
- `JackpotDisplayModel` — all jackpot counters + machine identity
- `DoubleUpViewportModel` — trail cards, dealer, challenger, labels, isLucky5Active

### 9.2 — Display model pipeline
- Backend DTOs → display model mapping in `game.js`
- UI reads display models only, never derives outcome semantics from CSS/timing state

**Verification**: All display values traceable to backend DTOs; no frontend-only outcome logic

---

## Phase 10: Testing & Validation (Est. 4h)

**Target**: Parity plan §"Test Plan"

### 10.1 — Screenshot baselines
- Capture at 720×1280 for:
  - Auth shell, lobby, idle cabinet, hold prompt, drawn win, Lucky5 active
  - Double-up shuffle, double-up resolved, menu overlay, wallet screen

### 10.2 — Interaction verification
- Cards deal left to right
- Hold lamps align with card columns
- DEAL DRAW = red, BET = green
- Jackpot highlight + FH rank update without layout shift
- Menu/wallet return without breaking session

### 10.3 — Regression checks
- No new frontend-only outcome logic
- Backend authoritative for balances, jackpots, double-up state
- All labels readable at portrait baseline without overlap
- Run full test suite: `dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj`
- Smoke test: `pwsh scripts/smoke-api.ps1`

---

## Phase 11: React Cabinet Port (Est. 8h, deferred)

After vanilla JS reaches parity:
- Create `src/web/components/cabinet-vnext/` subtree
- Port the validated vanilla layout to React components matching the plan's layer list:
  - `shell-screen-router`, `cabinet-frame`, `paytable-panel`, `credit-stake-panel`
  - `label-band`, `card-stage`, `win-amount-display`, `machine-info-block`
  - `double-up-info-band`, `control-deck`, `menu-overlay`
  - `lobby-shell`, `wallet-shell`, `admin-shell`
- Use clone assets from `wwwroot/assets/`
- Connect SignalR for real-time updates
- Add TypeScript types matching `CabinetDisplayModel`, etc.

---

## Dependency Graph

```
Phase 0 (foundation)
  ├── Phase 1 (coordinate system) ← blocks all visual phases
  │     ├── Phase 2 (labels) 
  │     ├── Phase 3 (cards)
  │     └── Phase 4 (control deck)
  ├── Phase 5 (jackpot block) ← depends on Phase 1 + 2
  ├── Phase 6 (double-up) ← depends on Phase 3 + backend DTO changes
  ├── Phase 7 (shell/menu) ← mostly independent, light Phase 1 dep
  └── Phase 8 (pace) ← depends on Phase 3 + 5
Phase 9 (types) ← can start after Phase 1, best after Phase 6
Phase 10 (testing) ← after all above
Phase 11 (React port) ← after Phase 10 validates vanilla
```

## Risk Register

| Risk | Mitigation |
|------|-----------|
| Button image assets don't fit new coordinate grid | Resize/crop; assets are high-res PNGs |
| Backend DTO changes break existing clients | Add fields only, never remove; default values for new fields |
| Double-up trail requires backend tracking changes | Scope carefully; may need server-side CardTrail list |
| CSS coordinate overhaul breaks existing game states | Test each state individually; keep old CSS as fallback branch |
| Pace animations feel wrong without real device testing | Parameterize all timing values; test on mobile viewport |

## Estimated Total Effort

| Phase | Hours |
|-------|-------|
| 0 — Foundation | 2 |
| 1 — Coordinate system | 4 |
| 2 — Labels | 6 |
| 3 — Cards | 4 |
| 4 — Control deck | 4 |
| 5 — Jackpot block | 4 |
| 6 — Double-up | 6 |
| 7 — Shell/menu | 6 |
| 8 — Pace | 3 |
| 9 — Types | 2 |
| 10 — Testing | 4 |
| 11 — React port (deferred) | 8 |
| **Total** | **~53h** |

## Guardrails (from vNext completion plan)

Do **not** change:
- Lebanese paytable semantics
- Two Pair minimum qualifying hand
- Ace-always-wins double-up behavior
- Lucky 5 switch-only no-lose behavior and multipliers
- Deterministic pre-shuffled outcome logic
- Backend game engine (`server/src/Lucky5.Domain/Game/CleanRoom/`)
- Retro cabinet visual philosophy


/create-prompt 

