# Lucky5 Godot Cabinet

This is the playable Godot 4 portrait cabinet for Lucky5. It is intentionally a client shell: cards, wins, double-up outcomes, jackpot movement, machine closure, cash-in, and cash-out are all applied only from backend snapshots or command results.

## Runtime contract

Set these environment variables before running `res://scenes/CabinetRoot.tscn`:

```bash
LUCKY5_API_BASE_URL=http://127.0.0.1:8080
LUCKY5_ACCESS_TOKEN=<player bearer token>
LUCKY5_MACHINE_ID=1
```

The scene boots `res://data/fixture_snapshot.json` immediately, then hydrates from:

- `GET /api/Game/machine/{machineId}/cabinet-snapshot`
- `POST /api/Game/cabinet/command`
- `POST /api/Game/machine/{machineId}/cabinet-replay`

## Playable controls

- CASH IN sends `cash_in` with an amount from the input box.
- BET cycles locally between backend min and max bet, then sends a non-mutating `bet_change` telemetry command.
- DEAL sends `deal` with the selected bet.
- Card taps toggle a local hold preview; DRAW sends those `hold_indexes` to the backend.
- BIG/SMALL send `double_up_guess`; the backend starts double-up automatically when allowed.
- TAKE HALF sends `take_half`.
- TAKE SCORE sends `take_score` while a round is active, or `cash_out` when only cash-out is available.
- RECONNECT requests replay from the last applied state/sequence cursor.

## Flutter parity notes

The uploaded Flutter web artifact is compiled/minified JavaScript, so this client ports behavior patterns rather than copying generated code: backend event vocabulary, foreground/background heartbeat, reconnect replay, cash controls, local hold preview, double-up controls, and server-driven button enablement.

## Authority rules

Godot does not create cards, resolve hands, mutate wallet balances, advance jackpots, decide double-up, or settle payouts. Every visible state change is driven by a `cabinet.v1` snapshot returned from the server.
