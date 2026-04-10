# Lucky5 Clone-Parity Vertical Slice Design

Date: 2026-04-10

## Objective

Implement an adapter-first vertical slice to achieve Lucky5 clone-parity. This includes integrating the vNext cabinet bundle from `plans/patch/`, extending backend display contracts, and hardening non-critical persistence snapshots.

## Guardrails

- `game.js` in `server/src/Lucky5.Api/wwwroot/js/` remains the gameplay authority for this slice.
- Adapter integration is additive and reversible via feature flags.
- Authoritative game logic in `CleanRoom/` remains untouched.
- Persistence changes are limited to non-critical snapshots to avoid session corruption.

## Architecture

### Adapter Integration
- Integrate the adapter bundle from `plans/patch/` into `index.html` after the legacy runtime.
- The adapter manages:
    - Fixed 720x1280 zoning and portrait framing.
    - Face-up deal rendering.
    - Draw choreography and pacing.
    - Double-up trail placement and animations.
    - Idle and title presentation (cabinet polish).

### Display Layer
- **Display-Model Mapper**: Add a lightweight mapper in the backend for cabinet-facing aggregates to ensure the frontend receives stable, display-ready data.
- **Authority**: The frontend `game.js` continues to drive the SignalR loop, but the brand-new adapter layer intercepts and enhances the visual presentation.

## Backend Contract Extensions

### Jackpot Information
Extend `Lucky5.Application.Dtos.JackpotInfoDto` with the following properties (if needed):
- `MachineSerial`: Distinct serial for the virtual machine.
- `MachineSerie`: Machine series identifier.
- `MachineKent`: Machine kent identifier.
*Note: These extensions remove the need for frontend guess-work during machine initialization.*

### Double-Up Feed
- Use `CardTrail` and `IsLucky5Active` from `Lucky5.Application.Dtos.DoubleUpResultDto` as the canonical feed for double-up display.
- Ensure the adapter accurately reflects the trail based on this backend-provided state.

## Persistence Hardening

Implement moderate persistence hardening for non-critical snapshots:
- Interface: `Lucky5.Infrastructure.Persistence.IPersistentStateStore`.
- Service: `Lucky5.Infrastructure.Persistence.PersistentStateCheckpointService`.
- Scope: Focus on session metadata and non-critical snapshots that can be safely recovered without full-state rehydration requirements for every frame.

## Feature Flag Policy

- Locate the feature flag in `server/src/Lucky5.Api/wwwroot/js/game-config.js`.
- The adapter bundle must be toggleable independently.
- **Fallback**: If the flag is disabled, the cabinet must fall back to the legacy vNext stage rendering without regression.

## Verification Bar

1. **Backend**:
    - Build success for `Lucky5.Api`, `Lucky5.Domain`, and `Lucky5.Infrastructure`.
    - All existing unit and integration tests must pass.
2. **Frontend Parity**:
    - Browser-based verification on a strict 720x1280 baseline.
    - Visual parity with legacy rendering for state-transitions (Deal, Draw, Hold).
3. **No-Regression Gate**:
    - Mandatory validation run before enabling persistence snapshotting logic to ensure state storage does not introduce lag or heap growth.

## Rollout Sequence

1. **Bundle Integration**: Drop files from `plans/patch/` and wire into `index.html` behind the feature flag (disabled by default).
2. **Adapter Refinement**: Fix adapter issues until browser parity on the 720x1280 baseline passes.
3. **Contract Landing**: Implement `JackpotInfoDto` extensions and the display-model mapper.
4. **Validation Phase 1**: Run the no-regression gate for the integrated frontend.
5. **Persistence Enablement**: Implement and enable non-critical snapshotting via `IPersistentStateStore` and `PersistentStateCheckpointService`.
6. **Final Verification**: Comprehensive pass of backend tests, frontend parity, and performance checks.

## Success Criteria

- Cabinet runs at 720x1280 with vNext polish (deal/draw/double-up animations).
- Backend provides machine metadata (Serial/Serie/Kent) via `JackpotInfoDto`.
- Double-up trail matches backend `CardTrail` authority perfectly.
- Non-critical snapshots are persisted without affecting gameplay performance.
- Feature flag allows instant rollback to legacy visuals.
