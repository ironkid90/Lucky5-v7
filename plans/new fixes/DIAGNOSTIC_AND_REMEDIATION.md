# Lucky5 Azure Diagnostic and Remediation Protocol

## High-confidence root causes found from the current frontend

### 1. Layout distortion / visibility regression

The current frontend combines two incompatible layout systems:

- `game.css` constrains `#game-container` to `max-width: 540px` and uses fluid-height card sizing.
- `cabinet-layout-vnext.css` tries to impose a fixed 720x1280 portrait cabinet using absolute zones.

This creates a double-scaling conflict that can crop, squash, or misalign the cabinet depending on the Azure-hosted browser viewport.

Additionally, `index.html` contains a duplicated `btn-take-score` control inside `#bottom-row`, producing a malformed 3-column deck layout and increasing the chance of hidden or overlapping controls.

### 2. Game loop breaking after the first hand

`game.js` currently drives the same visual surface through multiple render paths at once:

- legacy `renderCards(...)`
- `CabinetStage.dealCards(...)`
- `CabinetStage.drawCards(...)`
- manual post-draw DOM animation loop on `.card-slot`

This means the same `#card-area` is rebuilt and animated by multiple code paths during deal and draw. On slower or production browsers this can desynchronize state, create stale nodes, and leave controls visually stuck after the initial hand.

### 3. Azure environment / transport hardening gaps

The server is configured to respect `PORT` / `WEBSITES_PORT` and `CORS:ALLOWED_ORIGINS`, but the client hard-codes `const API = ''`, assuming same-origin deployment. If Azure introduces a separate frontend origin, custom domain mismatch, or reverse-proxy path prefix, REST and SignalR can silently drift.

`apiCall()` also assumes all failing responses are valid JSON, which is fragile on Azure when upstream failures return HTML error pages.

## Required remediation plan

### Frontend layout
1. Remove duplicate controls and duplicate stylesheet includes.
2. Remove the `max-width: 540px` clamp from `#game-container`.
3. Introduce an explicit cabinet frame that scales a 720x1280 reference surface as one unit.
4. Use a single viewport sizing variable (`--app-vh`) updated from JS to avoid mobile/Azure WebView chrome distortion.

### Rendering path
1. Create cabinet-aware render helpers.
2. Use **one** main-hand deal path and **one** draw path.
3. If `CabinetStage` exists, use it exclusively for card-stage mutations.
4. Remove the legacy manual post-draw animation loop.

### Client-server handshake
1. Add an overridable API base resolver.
2. Harden `apiCall()` against HTML/non-JSON failures.
3. Log SignalR lifecycle transitions in debug mode.
4. Keep machine-session refresh after draw/take-score/take-half on the server-authoritative path.

### Azure verification runbook
1. Confirm WebSockets are enabled in App Service.
2. Confirm `CORS:ALLOWED_ORIGINS` includes the real deployed frontend origin.
3. Confirm frontend and API are either same-origin or that `LUCKY5_API_BASE_URL` is injected.
4. Capture browser console + network on the first failing hand.

