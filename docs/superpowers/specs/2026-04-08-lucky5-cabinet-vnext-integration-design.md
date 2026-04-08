# Lucky5 Cabinet VNext Integration Design

Date: 2026-04-08

## Objective

Integrate the `plans/lucky5_refactor_patch` cabinet frontend bundle into the vanilla JS Lucky5 cabinet in `server/src/Lucky5.Api/wwwroot/` while preserving current backend contracts, current gameplay semantics, and the retro cabinet feel.

Success means:

- the four new vnext runtime modules are integrated into the vanilla cabinet
- the cabinet still boots and runs through the existing shell/game flow
- compatibility issues between the new orchestrator layer and the current cabinet are resolved inside the repo rather than deferred
- debugging hooks are available for frontend inspection
- compatibility checks and regression tests cover the new integration points

## Constraints

- `docs/` remains the active source of truth
- `server/src/Lucky5.Domain/Game/CleanRoom/` is authoritative for deterministic game rules and must not be changed
- backend API routes, SignalR semantics, machine/session logic, and payout logic must not change
- `sources/` is reference-only and must not be edited
- tests must run with `dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj`
- the cabinet must remain a portrait, retro, arcade-style surface rather than a modern dashboard

## Current State

The current cabinet already contains:

- `game.js` as the main runtime/controller
- `cabinet-stage-vnext.js` for card/control presentation
- `cabinet-pace-vnext.js` for pacing animations
- `cabinet-shell-vnext.js` for shell/lobby/menu behavior
- `cabinet-layout-vnext.css`, `cabinet-labels-vnext.css`, and `cabinet-shell-vnext.css` for portrait cabinet styling

The proposed patch bundle adds:

- `cabinet-state-vnext.js`
- `cabinet-audio-vnext.js`
- `cabinet-transition-vnext.js`
- `cabinet-orchestrator-vnext.js`
- `cabinet-frame-vnext.css`
- `index.html` and `game-config.js` wiring for the new modules

The current `index.html` also has a real markup bug: `btn-take-score` appears twice in the bottom row. That must be fixed as part of integration.

## Recommended Approach

Adopt the full bundle direction requested by the user, but as a guarded integration rather than a literal patch replay.

This means:

- add the new vnext modules to `wwwroot/js/`
- add the new frame stylesheet to `wwwroot/css/`
- wire the new modules into `index.html`
- extend `game-config.js` with the cabinet/audio config expected by the new modules
- adapt the orchestrator where necessary so it coexists with the current cabinet runtime instead of assuming a pristine target
- preserve the existing stage, pace, and shell modules as the visible DOM workers under the new adapter layer

## Architecture

### Runtime ownership

- `game.js` remains the authoritative gameplay/controller script
- `cabinet-stage-vnext.js` remains the visual card/button stage layer
- `cabinet-pace-vnext.js` remains the animation timing layer
- `cabinet-shell-vnext.js` remains the shell/lobby/menu layer
- `cabinet-state-vnext.js` becomes the synchronized read model for machine/presentation state
- `cabinet-audio-vnext.js` becomes the centralized audio queue
- `cabinet-transition-vnext.js` becomes the frame planner and timing/debug surface
- `cabinet-orchestrator-vnext.js` becomes the adapter layer that patches selected legacy hooks and routes key visual actions through the planner

### Data flow

1. `game.js` mutates the current runtime state or calls an existing render/helper function.
2. The orchestrator intercepts selected functions that are safe and useful to patch.
3. `CabinetState.syncFromRuntime()` snapshots the current machine and presentation state from globals and DOM.
4. `CabinetTransition.dispatch(...)` sequences presentation work.
5. Existing stage/pace/shell modules still perform the visible DOM work.
6. Debug helpers read from the unified state/planner layer.

## Integration Plan

### 1. Asset and config wiring

- Copy the four JS modules from `plans/lucky5_refactor_patch/js/` into `server/src/Lucky5.Api/wwwroot/js/`
- Copy `cabinet-frame-vnext.css` into `server/src/Lucky5.Api/wwwroot/css/`
- Update `index.html` to load the new CSS and JS in an order compatible with the current cabinet boot sequence
- Extend `game-config.js` with:
  - `cabinet.fps`
  - `cabinet.layout`
  - `audio.events`

### 2. Markup and DOM compatibility

- Remove the duplicate `btn-take-score` button from the bottom row
- Preserve all ids and selectors currently used by `game.js`, existing CSS, and tests
- Keep menu, lobby, wallet, admin, and game screens structurally unchanged except for required compatibility fixes

### 3. Orchestrator compatibility hardening

The bundle orchestrator cannot be integrated verbatim without review because it patches globals aggressively. The repo integration should harden it by:

- only patching globals that actually exist
- failing soft when optional hooks are absent
- avoiding bootstrap failure if one patched hook throws
- preserving access to original functions for debugging
- keeping button-state rebuilding aligned with current machine-closed, double-up, and hold-state rules
- ensuring the orchestrator does not become the source of truth for gameplay

### 4. Frame CSS scoping

`cabinet-frame-vnext.css` should support the portrait stage and CRT framing without destabilizing existing layout/style rules in:

- `game.css`
- `cabinet-layout-vnext.css`
- `cabinet-labels-vnext.css`
- `cabinet-shell-vnext.css`

If conflicts appear, the repo version should be narrowed rather than forcing a full style takeover.

## Debugging Additions

The integration must include explicit debugging surfaces:

- `window.render_game_to_text()` for stable machine/presentation/state inspection
- `window.advanceTime(ms)` as a frontend timing/debug helper
- orchestrator access to original patched functions for debugging
- guarded install behavior so missing hooks do not break cabinet boot

`advanceTime(ms)` is a frontend debug control only. It is not a guarantee of end-to-end gameplay determinism and must not be represented as such.

## Testing And Verification

### Static verification

Run syntax checks on:

- `server/src/Lucky5.Api/wwwroot/js/cabinet-state-vnext.js`
- `server/src/Lucky5.Api/wwwroot/js/cabinet-audio-vnext.js`
- `server/src/Lucky5.Api/wwwroot/js/cabinet-transition-vnext.js`
- `server/src/Lucky5.Api/wwwroot/js/cabinet-orchestrator-vnext.js`
- any touched existing JS file, especially `game.js`

### Automated regression coverage

Run:

```powershell
dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj
```

Add or update regression tests as needed for:

- vnext script references in `index.html`
- duplicate `btn-take-score` removal
- `game-config.js` cabinet/audio config presence
- debug hook presence in the integrated frontend
- compatibility expectations that can be checked statically without browser runtime execution

### Browser smoke verification

If the local app can be run successfully, verify:

- auth to lobby flow
- machine select to game flow
- deal cadence
- draw cadence
- double-up entry and trail updates
- menu open/close and back-to-lobby flow
- machine-close messaging and button-state behavior
- `render_game_to_text()` output sanity

## Risks

### Primary risks

- orchestrator monkey-patching may conflict with the current cabinet boot/runtime assumptions
- frame CSS may overlap existing portrait layout rules
- duplicate responsibility between `game.js` and orchestrator-driven button/render state may create drift
- audio queueing may subtly change interaction feel if over-applied

### Mitigations

- patch only verified legacy functions
- keep gameplay state authoritative in `game.js`
- keep DOM ids and existing screen structure stable
- test against the current frontend regression suite
- add targeted regression checks for new integration points
- do a browser smoke pass before claiming the integration is complete

## Out Of Scope

- changing backend endpoints or response shapes
- changing CleanRoom gameplay logic
- redesigning the cabinet into a different visual style
- replacing the vanilla JS cabinet with the React cabinet
- mobile-specific redesign work

## Implementation Notes

- prefer minimal repo-native edits over replaying the bundle patch mechanically
- preserve current conventions and existing improvements already in `game.js`
- treat the bundle as a source of modules and ideas, not as a source of truth over the repo

## Acceptance Criteria

- new vnext modules are present and loaded by the vanilla cabinet
- existing shell/game flow still works with the integrated adapter layer
- duplicate `btn-take-score` markup is removed
- debug hooks are exposed
- automated tests pass
- browser smoke verification is either completed successfully or reported clearly if blocked
