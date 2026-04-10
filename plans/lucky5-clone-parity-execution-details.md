# Lucky5 Clone-Parity Major Upgrade: Technical Execution Plan

Date: 2026-04-10
Status: Implementation Ready
Target: Phase 4.0 (Parity and Bug Fixes)

## 1. Objective
Achieve 1:1 visual and interaction parity between the Lucky5 web cabinet and legacy hardware assets. This is a frontend-led overhaul with targeted backend DTO enhancements and critical gameplay bug fixes.

## 2. Phase 0: Asset and Backend Audit
- [ ] **Asset Verification**:
    - [ ] Confirm all clone button images (normal and `_on.png`) in `server/src/Lucky5.Api/wwwroot/assets/images/buttons/`.
    - [ ] Verify 52 card PNGs + `bside.png`.
    - [ ] Ensure `board.png` (wood texture) and CRT scanline assets are present.
    - [ ] Verify `ARCADE.ttf` exists and is correctly mapped in CSS.
- [ ] **Backend DTO Extension**:
    - [ ] [`Lucky5.Domain.Game.CleanRoom.MachinePolicyResolution`](server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicyResolution.cs): Ensure internal telemetry matches requirements.
    - [ ] [`JackpotInfoDto`](server/src/Lucky5.Infrastructure/Services/GameService.cs): Add `MachineSerial`, `MachineSerie`, and `MachineKent` (provisional/static for now per AGENTS.md).
    - [ ] [`DoubleUpResultDto`](server/src/Lucky5.Infrastructure/Services/GameService.cs): Add `CardTrail` (list of previous cards) and `IsLucky5Active` (boolean flag).

## 3. Phase 1: Fixed Coordinate CSS Overhaul
Target: Absolute layout mirroring the hardware display.
- [ ] Refactor `game.css` to use a strict `720x1280` fixed container.
- [ ] Standardize the vertical percentage stack:
    - `00-15%`: Paytable + Credit/Stake zone.
    - `15-19%`: Contextual Label Band (Lucky5 active, etc.).
    - `19-38%`: Card Stage (5 slots).
    - `38-42%`: Win Amount Display.
    - `42-53%`: Machine Info / Jackpot Block.
    - `53-67%`: HOLD lamps.
    - `67-84%`: Main Action Row (DEAL DRAW Red, BET Green).
    - `84-97%`: Bottom Control Row (TAKE HALF, MENU, TAKE SCORE).
- [ ] Apply Wood Texture: Map `board.png` to the control deck and outer framing.
- [ ] CRT Layer: Implement a fixed scanline overlay on the primary playfield (0-53% area).

## 4. Phase 2: Typography and Labels
- [ ] **Rainbow Paytable**:
    - RF: Red/White glow.
    - SF: Pure Red.
    - 4K: Cyan.
    - FH: Yellow.
    - Flush: Red.
    - Straight: Green.
    - 3K: Cyan.
    - 2P: Yellow.
- [ ] **Contextual Banners**:
    - Implement "LUCKY 5 IS ACTIVE" in gold/cyan.
    - Implement "HI LO GAMBLE" and "ACE COUNTS HI OR LO" in the secondary label band.
    - Ensure pixel font at exact scale (no sub-pixel anti-aliasing).

## 5. Phase 3: Card Stage Choreography & Bug Fixes
- [ ] **Bug Fix: Face Down Cards**: Fix logic in `game.js` that current renders cards as face-down during the active hand phase.
- [ ] **Deal Animation**: Implement left-to-right deal with a `90–120ms` stagger.
- [ ] **Draw Animation**: Implement `80–100ms` in-place flip transitions for unheld cards.
- [ ] **Asset Migration**: Replace all CSS cards with exact PNG asset mapping.

## 6. Phase 4: Double-Up Rebuild & Bug Fixes
- [ ] **Bug Fix: Card Placement**: Fix current double-up rendering where cards appear in wrong slots or overflow the stage.
- [ ] **The Trail**: Build a 5-slot trail (4 historical dealer cards + 1 active challenger).
- [ ] **Shuffle Animation**: Implement rapid `~80ms` shuffling during the "wait for result" phase.
- [ ] **Lucky5 Presentation**: Implement the white/gold screen flash and special banner flicker for Lucky5 activations (Dealer 5S).

## 7. Phase 5: Button Deck & Shell Integration
- [ ] **Image Buttons**: Replace CSS buttons with image assets.
    - RED for DEAL DRAW.
    - GREEN for BET.
    - Use `*_on.png` variants for the active duration of `mousedown`/`touchstart`.
- [ ] **Menu Panel**: Mount the menu overlay directly onto the cabinet dashboard; ensure screen area for play is maximized while keeping buttons reachable and "hardware-dense".
- [ ] **Rolling Meters**:
    - Wins count-up: `1.5–5s` duration.
    - Jackpots count-up: `10–15s` duration.

## 8. Verification Baseline
- [ ] Portrait 720x1280 screenshot verification.
- [ ] Multi-turn Double-Up trail accuracy check.
- [ ] Live SignalR jackpot sync validation.
