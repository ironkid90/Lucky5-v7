# Lucky5 frontend cabinet refactor patch bundle

This bundle applies a best-effort architecture refactor on top of the current `wwwroot` cabinet frontend without changing backend contracts or moving away from vanilla JS.

## What this patch adds

- `cabinet-state-vnext.js`
  - central `MachineState` + `PresentationState` store
  - runtime synchronization from existing `game.js` globals
  - selectors for input legality derived from state instead of DOM drift
- `cabinet-audio-vnext.js`
  - small priority-queued audio engine
  - first-class event mapping for button press, invalid, deal, draw, collect, Lucky5, machine-close
- `cabinet-transition-vnext.js`
  - frame-count based planner at `GAME_CONFIG.cabinet.fps`
  - deterministic sequencing helpers for deal, draw, double-up, win collection, jackpot fill, Lucky5, machine-close
  - `window.advanceTime(ms)` hook for deterministic automation
- `cabinet-orchestrator-vnext.js`
  - installs after legacy scripts and monkey-patches rendering primitives and state sync points
  - routes major render actions through the new planner
  - rebuilds button enablement from selectors
  - exposes `window.render_game_to_text()` for gameplay/state inspection
- `cabinet-frame-vnext.css`
  - enforces a 720x1280 portrait cabinet stage
  - absolute zone anchoring
  - subtle CRT overlay and fixed control deck rhythm
- `apply.patch`
  - minimal integration patch for `index.html` and `game-config.js`

## Why this shape

The current repo already has `cabinet-stage-vnext.js`, `cabinet-pace-vnext.js`, and `cabinet-shell-vnext.js`. This patch does not replace them. It adds the missing orchestration layer so existing stage and pace modules can behave like hardware subsystems rather than direct ad-hoc helpers.

## Source references used

- Source cabinet screenshots supplied in the task (`Screenshot 2026-03-11 005758.png`, `012723.png`, `012828.png`, `012853.png`)
- OCR/video transcript supplied in `Recording-2026-04-05-112331_compressed_(1).zip`

## Integration steps

1. Copy `js/*.js` into `server/src/Lucky5.Api/wwwroot/js/`
2. Copy `css/cabinet-frame-vnext.css` into `server/src/Lucky5.Api/wwwroot/css/`
3. Apply the changes in `apply.patch`
4. Bump cache-buster query strings if your repo conventions require it

## Verification

Static checks run for the new JS files in this bundle:

```bash
node --check server/src/Lucky5.Api/wwwroot/js/cabinet-state-vnext.js
node --check server/src/Lucky5.Api/wwwroot/js/cabinet-audio-vnext.js
node --check server/src/Lucky5.Api/wwwroot/js/cabinet-transition-vnext.js
node --check server/src/Lucky5.Api/wwwroot/js/cabinet-orchestrator-vnext.js
```

Recommended next verification inside the repo:

```bash
node --check server/src/Lucky5.Api/wwwroot/js/game.js
cd server && dotnet run --project tests/Lucky5.Tests/Lucky5.Tests.csproj
```

Then run the cabinet in a browser and verify:

- deal/draw cadence
- double-up trail updates
- menu / lobby / wallet transitions
- session restore via `active-round`
- machine-close collect flow
- `window.render_game_to_text()` output
- `window.advanceTime(ms)` hook
