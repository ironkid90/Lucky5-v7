# Godot playable cabinet expansion - 2026-05-24

This update turns the Godot migration slice into a playable backend-authoritative cabinet client without moving game authority out of ASP.NET Core.

## Added

- Godot 4 project at `godot/cabinet/`.
- Fixture-first boot so the cabinet renders in editor/headless runs before the backend is reachable.
- HTTP hydration from `GET /api/Game/machine/{machineId}/cabinet-snapshot`.
- Idempotent `cabinet.v1` command envelopes for cash-in, cash-out, deal, draw, double-up guesses, take-half, take-score, heartbeat, and reconnect/lobby signals.
- Replay recovery against `POST /api/Game/machine/{machineId}/cabinet-replay` using the last applied `state_version` and `sequence_number`.
- Server-driven button enablement with local hold preview only; draw remains authoritative because hold indexes are sent with the draw command.
- Flutter-inspired control vocabulary: CASH IN, BET, DEAL/DRAW, CANCEL HOLD, BIG, SMALL, TAKE HALF, TAKE SCORE, CASH OUT, RECONNECT.

## Not changed

- No RNG, payout, wallet, jackpot, or double-up resolver was added to Godot.
- Backend contract types remain the source of truth.
- Existing vanilla web cabinet and Flutter client remain untouched.

## Manual smoke

1. Start the backend:

   ```bash
   dotnet run --project server/src/Lucky5.Api/Lucky5.Api.csproj
   ```

2. Obtain a normal player bearer token from the existing login flow.
3. Run Godot with:

   ```bash
   LUCKY5_API_BASE_URL=http://127.0.0.1:8080 \
   LUCKY5_ACCESS_TOKEN=<player bearer token> \
   LUCKY5_MACHINE_ID=1 \
   godot4 --path godot/cabinet
   ```

4. Expected result:
   - fixture renders instantly;
   - backend snapshot replaces fixture credits, cards, jackpots, state, and buttons;
   - cash-in enables deal;
   - deal returns cards;
   - card taps mark local hold preview;
   - draw sends `hold_indexes` and applies the returned result snapshot;
   - wins enable BIG/SMALL, TAKE HALF, and TAKE SCORE as provided by the backend button map;
   - backend restart/disconnect shows recovery text and replay/snapshot recovery restores the scene.

## Review checklist

- Confirm `schema_version` remains `cabinet.v1`.
- Confirm command idempotency keys are unique per user action.
- Confirm stale-state responses apply the returned snapshot before re-enabling controls.
- Confirm Godot never modifies credit totals without a backend snapshot.
- Confirm disabled buttons follow `snapshot.buttons[*].enabled` and not local guesses.
