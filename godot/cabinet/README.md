# Lucky5 Godot Cabinet

This is the playable Godot 4 portrait cabinet for Lucky5. It is intentionally a client shell: cards, wins, double-up outcomes, jackpot movement, machine closure, cash-in, and cash-out are all applied only from backend snapshots or command results.

## Runtime contract

Set these environment variables before running `res://scenes/CabinetRoot.tscn`:

```bash
LUCKY5_API_BASE_URL=http://127.0.0.1:8080
LUCKY5_ACCESS_TOKEN=<optional preloaded player bearer token>
LUCKY5_AUTH_USERNAME=<player username>
LUCKY5_AUTH_PASSWORD=<player password>
LUCKY5_MACHINE_ID=1
```

## Platform export lanes

The same `res://scenes/CabinetRoot.tscn` client is the source for all cabinet
targets. `godot/cabinet/export_presets.cfg` keeps three explicit lanes:

- `Windows Desktop` exports the kiosk build to `artifacts/godot-kiosk/`.
- `Web` exports a portrait PWA shell to `artifacts/godot-web/`.
- `Android` exports an unsigned portrait APK to `artifacts/godot-android/`.

All lanes exclude `addons/*` from the shipped package. The runtime cabinet does
not load editor plugins, and keeping them out reduces web/mobile payload size.

Use the Windows kiosk script for release packages because it enforces the
readiness gate and asset manifest policy. The web and Android presets are dev
compatibility lanes until signing, store policy, and device QA are approved:

```powershell
godot --headless --path godot/cabinet --export-release "Web" artifacts/godot-web/dev/index.html
godot --headless --path godot/cabinet --export-release "Android" artifacts/godot-android/dev/Lucky5Cabinet.apk
```

For the merged web app, export Godot into the ignored Next public bundle and
open `/godot` from the web server:

```powershell
.\scripts\godot\Export-GodotWebCabinet.ps1 -Clean
```

Android exports require local Android tooling and export templates. Web exports
must be served over HTTP(S); do not open the generated HTML from `file://`.

The scene boots `res://data/fixture_snapshot.json` immediately, then hydrates from:

- `GET /api/Game/machine/{machineId}/cabinet-snapshot`
- `POST /api/Game/cabinet/command`
- `POST /api/Game/machine/{machineId}/cabinet-replay`

When `LUCKY5_ACCESS_TOKEN` is absent, the cabinet authenticates with
`LUCKY5_AUTH_USERNAME` and `LUCKY5_AUTH_PASSWORD`, stores the returned bearer
token in memory, and re-authenticates on `401` recovery paths before requesting
another authoritative snapshot.

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
