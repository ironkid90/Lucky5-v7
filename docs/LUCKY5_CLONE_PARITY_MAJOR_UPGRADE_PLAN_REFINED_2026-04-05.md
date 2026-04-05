# Lucky5 Clone-Parity Major Upgrade Plan

Date: 2026-04-05
Status: Refined execution brief
Derived from: `docs/LUCKY5_SUCCESSOR_CLONE_PARITY_PLAN_2026-04-05.md`

## Summary

This plan turns the clone-parity brief into an implementation-ready sequence that is faithful to the current Lucky5 repo.

The goal is to bring Lucky5 to clone-level visual and interaction quality while preserving:

- the clean-room backend
- the Lebanese cabinet identity
- the current machine-credit and wallet semantics
- the current double-up rules and payout architecture

This is a **presentation and shell parity** upgrade, not a rules rewrite.

## Current State Summary

| Area | Vanilla JS (`server/src/Lucky5.Api/wwwroot/`) | React (`src/web/`) |
|------|-----------------------------------------------|--------------------|
| Shell screens | auth, lobby, wallet, admin, game | auth + in-cabinet machine selection only |
| Cabinet layout | portrait cabinet stack | dashboard-like cabinet plus side telemetry |
| Card rendering | clone PNG assets | CSS-rendered text cards |
| Control deck | clone button art + menu overlay | generic styled controls |
| Jackpot block | close to clone | simplified strip |
| Double-up viewport | trail-in-stage viewport | simplified side panel |
| Menu overlay | present | absent |
| Realtime | SignalR machine sync wired | no equivalent cabinet sync path |

## Execution Stance

The repo still declares the React cabinet as the active development target, but the vanilla JS cabinet is both the shipped playable surface and the closest clone-faithful implementation.

The correct execution strategy is:

1. use the vanilla JS cabinet as the **visual oracle and first parity surface**
2. validate layout, labels, shell flow, and pace there
3. then port the validated structure into the React cabinet as the long-term target

This is a deliberate sequencing choice, not a change in product direction.

## Non-Negotiable Guardrails

Do not change:

- Lebanese paytable semantics
- Two Pair minimum qualifying hand
- Ace-always-wins double-up behavior
- Lucky 5 switch-only no-lose behavior and multipliers
- deterministic pre-shuffled outcome logic
- backend authority for balances, machine state, jackpots, and double-up outcomes
- retro cabinet visual philosophy

Do not accidentally redesign:

- the machine-credit versus wallet model
- jackpot values entering machine credits
- `TAKE SCORE` and `TAKE HALF` settlement behavior
- REST-driven gameplay flow

SignalR can remain a sync layer for machine state and fanout. Gameplay actions stay REST-driven unless explicitly changed later.

## Phase 0: Foundation And Audit

### 0.1 Asset inventory

- Verify clone button images under `server/src/Lucky5.Api/wwwroot/assets/images/` and `.../buttons/`
- Verify all 52 card PNGs plus `bside.png`
- Verify `board.png`, `lucky5.png`, `splash.png`, `coin.png`
- Verify `ARCADE.ttf` and current pixel-font fallback usage in `game.css`
- Catalog any still-missing APK shell assets from:
  - `New folder/tools/APK_Toolkit_by_0xd00d/3 - Extracted/app-arm64-v8a-release.apk/assets/flutter_assets/assets/images`

### 0.2 Display contract audit

- Confirm existing backend DTO coverage:
  - `JackpotInfoDto` already has `FullHouse`, `FullHouseRank`, `FourOfAKindA`, `FourOfAKindB`, `ActiveFourOfAKindSlot`, `StraightFlush`
  - `DoubleUpResultDto` already has `Status`, `DealerCard`, `ChallengerCard`, `SwitchesRemaining`, `IsNoLoseActive`, `LuckyMultiplier`
  - `MachineSessionDto` already has `MachineCredits`, `CashOutThreshold`, `CanCashOut`, `IsMachineClosed`, `WalletBalance`
- Treat `duCardTrail`, Lucky5 flash state, and similar history as **frontend display state first**
- Do not add backend DTO fields unless a parity requirement cannot be rendered from existing data

### 0.3 Baseline verification

- Run:
  - `dotnet build server/Lucky5.sln -v minimal`
  - `dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj`
- Record current screenshots before layout work begins

### 0.4 Parallelization prep and DOM contract freeze

This is the only mandatory pre-parallel checkpoint.

- Freeze the target cabinet DOM map in `server/src/Lucky5.Api/wwwroot/index.html`
- Add stable wrappers, ids, and `data-*` hooks for:
  - paytable zone
  - top-right credit/stake zone
  - label band
  - card stage
  - win amount row
  - machine-info block
  - hold-lamp row
  - control deck rows
  - menu overlay
  - wallet and lobby shell blocks
- Extract CSS into isolated files:
  - `css/cabinet-layout-vnext.css`
  - `css/cabinet-labels-vnext.css`
  - `css/cabinet-shell-vnext.css`
- Extract JS into isolated files:
  - `js/cabinet-stage-vnext.js`
  - `js/cabinet-shell-vnext.js`
  - `js/cabinet-pace-vnext.js`
- Keep the old files loading until each new file is wired and verified
- After this checkpoint, treat `index.html` as frozen except for integration-only edits by the lead agent

## Phase 1: Cabinet Coordinate System

Target: one fixed portrait cabinet face.

- Refactor `server/src/Lucky5.Api/wwwroot/css/game.css` so the game screen behaves as a single `720x1280` portrait board
- Preserve this vertical map:
  - `0%-15%`: paytable + credit/stake
  - `15%-19%`: contextual label band
  - `19%-38%`: card stage
  - `38%-42%`: large win row
  - `42%-53%`: jackpot + machine-info block
  - `53%-67%`: hold lamps
  - `67%-84%`: main controls
  - `84%-97%`: bottom controls
- Desktop should scale the cabinet as one object with surrounding negative space
- Do not reflow playfield controls into side columns

Verification:

- screenshot at portrait baseline
- idle, hold, win, and double-up states all remain on the same machine face

## Phase 2: Label System And Text Hierarchy

Target: labels become machine components, not incidental UI text.

### 2.1 Paytable

- Match clone row colors as closely as the evidence supports
- Keep solid highlight box on the selected jackpot row
- Keep active hand highlighting distinct from jackpot selection
- Keep payout values stake-sensitive

### 2.2 Top-right counters

- `CREDIT`: green label, white value below
- `STAKE`: amber label, white value below
- lock top-right position

### 2.3 Machine-info block

- Preserve:
  - `SERIE - n`
  - `KENT /3 : n`
  - `4K A / SF / 4K B`
  - FH meter with selected rank
  - `S/N`
  - `4 OF A KIND WINS BONUS`
- Keep FH meter visually distinct:
  - black text and numbers inside white container
  - positioned directly beneath the lower paytable area, matching current vanilla cabinet direction

### 2.4 Contextual label bands

- Keep `LUCKY 5 IS ACTIVE` between paytable and cards
- Keep hold prompt language in the playfield, not in side UI
- Keep bottom info-bar messages centered:
  - `INSERT COIN`
  - `PLAY 5000`
  - win and collection messages
- Keep double-up label band:
  - `HI LO GAMBLE`
  - `ACE COUNTS HI OR LO`
  - Lucky5 rule text

Verification:

- side-by-side screenshot check against clone references for:
  - placement
  - readability
  - color roles
  - no overlaps

## Phase 3: Card Stage And Choreography

Target: fixed card columns with faithful motion.

- Keep five fixed base-game card slots
- Align each card vertically with:
  - paytable reading position
  - hold lamp
  - deck control slot
- Deal animation:
  - left to right
  - `90-120ms` stagger
  - drop-in from above
- Draw animation:
  - only unheld cards change
  - held cards stay physically stable
  - replacement timing `80-100ms`
- Use clone PNG cards only
- Use hold lamp assets, not generic CSS pills

Verification:

- deal one hand and verify left-to-right cadence
- hold selected cards and verify non-held-only replacement

## Phase 4: Control Deck Rebuild

Target: the lower third reads as cabinet hardware, not web buttons.

- Use clone button assets for:
  - HOLD
  - BIG
  - SMALL
  - CANCEL HOLD
  - DEAL DRAW
  - BET
  - TAKE HALF
  - TAKE SCORE
- Preserve Lebanese button color semantics:
  - DEAL DRAW red
  - BET green
- Keep physical order:
  - hold row
  - BIG / SMALL / CANCEL HOLD / DEAL DRAW / BET
  - TAKE HALF / MENU / TAKE SCORE
- MENU remains a dark circular machine-mounted control
- Pressed state should use `_on` asset variants where available

Verification:

- all actions visible
- all pressed states work
- no button order drift

## Phase 5: Win Amount And Jackpot Block

Target: clone-faithful center scoring stack.

- Keep large gold win amount directly beneath cards
- Keep A/B slot tag immediately beside the amount for relevant jackpot outcomes only
- Preserve current live jackpot block ordering from the vanilla cabinet
- Preserve active 4K slot highlight and FH rank presentation

Important constraint:

- `machineSerial`, `machineSerie`, and `machineKent` are not authoritative backend fields today
- For this phase, keep parity using the current vanilla approach unless a later explicit backend task formalizes them
- Do not claim these are already backend-tracked values

Verification:

- jackpot counters update
- active slot highlight changes correctly
- slot tag does not duplicate jackpot amount text

## Phase 6: Double-Up Viewport Rebuild

Target: retain clone-style double-up staging without unnecessary backend coupling.

- Keep double-up inside the main card stage
- Preserve the current legacy model:
  - local `duCardTrail`
  - one active challenger slot
  - one visible page of trail cards
- Keep labels:
  - `BIG / SMALL ?`
  - revealed `BIG` and `SMALL`
  - gold dealer emphasis
  - Lucky5 glow or lightning-like flash on `5S`
- Use the current `DoubleUpResultDto.Status` and card fields to drive presentation

Default rule:

- do **not** add `CardTrail` or `IsLucky5Active` to backend DTOs in this phase
- only add backend fields later if the current frontend model proves insufficient for parity

Verification:

- enter double-up
- verify trail progression
- verify challenger shuffle
- verify Lucky5 special presentation

## Phase 7: Menu Overlay And Shell Parity

Target: clone-like app shell without altering economy semantics.

### 7.1 Menu overlay

- keep machine-mounted overlay
- actions:
  - cash in
  - cash out
  - back to lobby
  - reset machine
  - logout

### 7.2 Shell states

- auth
- lobby
- wallet
- admin
- game

### 7.3 Visual family

- black play surfaces
- warm brown machine materials
- pixel or hard-edged compact typography
- shell screens feel like part of the same gambling machine system

### 7.4 Wallet and balance flow

- Preserve current Lucky5 economy:
  - wallet is the lobby balance
  - machine credits are the in-machine balance
  - `TAKE SCORE` and `TAKE HALF` settle into machine credits under current rules
  - cash-out moves machine credits back to wallet according to machine-session rules
- Do not introduce a new “move win to wallet” feature unless separately specified and approved

Verification:

- auth to lobby to wallet to lobby to game
- game to menu to lobby to game
- no machine-session loss from shell navigation

## Phase 8: Pace And Count-Up Polish

Target: tight clone-like presentation rhythm.

- Standard collection animation:
  - `1.5s - 5s`
- Jackpot fill:
  - `10s - 15s`
- Lucky5 flash:
  - brief white or gold flash
  - banner flicker
  - card glow
- No blocking modal pauses between result and next action

Verification:

- win collection pacing feels tight
- Lucky5 presentation is brief and readable

## Phase 9: React Port

Once the vanilla cabinet is validated, port the final structure into the React target.

- Build `src/web/components/cabinet-vnext/`
- Port these layers:
  - shell screen router
  - cabinet frame
  - paytable
  - credit/stake panel
  - label band
  - card stage
  - win amount display
  - machine-info block
  - double-up info band
  - control deck
  - menu overlay
  - lobby shell
  - wallet shell
  - admin shell
- Reuse validated clone assets from the vanilla surface
- Bring React cabinet to parity with the already-proven visual oracle

Verification:

- React cabinet matches the validated vanilla baseline screenshots for:
  - idle cabinet
  - win state
  - double-up state
  - menu and shell states introduced in the port
- React cabinet preserves current API semantics and does not reintroduce dashboard-style layout drift

## Test Plan

- portrait screenshot baselines for:
  - auth
  - lobby
  - idle cabinet
  - hold prompt
  - win state
  - Lucky5 active
  - double-up shuffle
  - double-up resolved
  - menu overlay
  - wallet
- interaction checks:
  - deal left to right
  - hold lamp alignment
  - DEAL DRAW red, BET green
  - jackpot and FH highlight behavior
  - no shell-navigation state loss
- backend verification:
  - `dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj`
  - `pwsh scripts/smoke-api.ps1`

## Effort Estimates

| Phase | Hours |
|------|-------|
| 0.1-0.3 Foundation and audit | 2 |
| 0.4 Parallelization prep and DOM contract freeze | 3 |
| 1 Cabinet coordinate system | 4 |
| 2 Label system and text hierarchy | 5 |
| 3 Card stage and choreography | 4 |
| 4 Control deck rebuild | 4 |
| 5 Win amount and jackpot block | 3 |
| 6 Double-up viewport rebuild | 5 |
| 7 Menu overlay and shell parity | 5 |
| 8 Pace and count-up polish | 3 |
| 9 React port | 8 |
| Validation sweep and integration | 4 |
| **Total** | **~46h** |

## Parallel Execution Model

After Phase `0.4`, the upgrade can be split across **3 parallel execution instances** with low overlap.

### Agent 1: Cabinet frame, labels, and jackpot surface

Owns:

- `server/src/Lucky5.Api/wwwroot/css/cabinet-layout-vnext.css`
- `server/src/Lucky5.Api/wwwroot/css/cabinet-labels-vnext.css`

Responsibilities:

- portrait coordinate system
- paytable layout
- credit/stake panel
- label band
- win amount row
- machine-info block
- jackpot highlight styling

Must not edit:

- shell navigation logic
- double-up sequencing logic
- wallet semantics

### Agent 2: Card stage, control deck, and double-up presentation

Owns:

- `server/src/Lucky5.Api/wwwroot/js/cabinet-stage-vnext.js`
- `server/src/Lucky5.Api/wwwroot/js/cabinet-pace-vnext.js`

Responsibilities:

- deal and draw choreography
- hold-lamp behavior
- control deck press-state behavior
- double-up viewport rendering
- Lucky5 flash and count-up polish

Must not edit:

- shell navigation
- lobby or wallet DOM
- backend DTOs unless Phase 6 explicitly proves they are required

### Agent 3: Shell, menu, and integration flow

Owns:

- `server/src/Lucky5.Api/wwwroot/css/cabinet-shell-vnext.css`
- `server/src/Lucky5.Api/wwwroot/js/cabinet-shell-vnext.js`

Responsibilities:

- auth, lobby, wallet, admin shell styling
- menu overlay behavior
- back-to-lobby, wallet, and admin transitions
- machine-session-safe shell routing
- final integration wiring in the frozen DOM hooks

Must not edit:

- card-stage choreography
- jackpot visual rules
- settlement semantics

### Lead agent integration rule

One lead agent owns:

- final `index.html` integration edits after Phase `0.4`
- script and stylesheet load order
- cross-workstream conflict resolution
- final validation sweep

No other agent should edit `index.html` after the DOM contract freeze.

## Parallel Dependency Notes

- Phase `0.4` is the hard gate before any parallel work starts.
- Agent 1 and Agent 3 can run in parallel immediately after `0.4`.
- Agent 2 can start after the card-stage hooks from `0.4` exist.
- Phase `6` depends on the card-stage structure from Phase `3`.
- Phase `8` depends on Agent 2’s stage and collection work.
- React port does not start until the vanilla cabinet passes validation.

## Estimated Sequence

1. foundation and audit
2. DOM contract freeze and file split
3. parallel workstream A: cabinet frame and labels
4. parallel workstream B: stage, controls, and double-up
5. parallel workstream C: shell and menu parity
6. integration sweep
7. pace polish
8. validation sweep
9. React port

## Default Assumptions

- vanilla JS is the first parity surface
- React remains the long-term target
- clone assets can be reused aggressively where they improve fidelity
- backend contract changes are additive and minimal-by-default
- frontend display state should remain frontend-owned unless a true backend truth is missing
- the safest way to parallelize this work is to freeze the DOM first, then split ownership by new partial CSS and JS files instead of editing the current monolithic files concurrently
