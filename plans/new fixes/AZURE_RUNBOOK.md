# Azure Runbook

## App Service settings to verify

- `WEBSITES_PORT` or `PORT`
- `ASPNETCORE_ENVIRONMENT`
- `CORS__ALLOWED_ORIGINS`
- `LUCKY5_API_BASE_URL` if frontend and API are split across origins

## Platform toggles

- WebSockets: Enabled
- ARR affinity: keep default unless sticky-session behavior is explicitly disabled and SignalR strategy is updated
- Always On: Enabled

## Browser diagnostics on production

1. Open devtools on the deployed build.
2. Reload with `?debug=1`.
3. Verify `/api/Game/machine/{id}/session`, `/api/Game/cards/deal`, `/api/Game/cards/draw`, and `/CarrePokerGameHub/negotiate` all return 200.
4. On the first broken hand inspect console for:
   - duplicate id warnings
   - non-JSON response errors
   - SignalR reconnection failures
5. Capture `window.render_game_to_text()` after:
   - machine open
   - first deal
   - first draw
   - failure point

## Expected success condition

- cabinet remains fully visible without horizontal squashing
- controls occupy one row for bottom deck
- deal → hold → draw → win/lose → next hand cycle continues without DOM freeze
