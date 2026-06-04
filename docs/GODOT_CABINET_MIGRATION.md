# Godot cabinet migration — finalized

Godot 4 portrait cabinet is now the default playable client for Lucky5.

## Status

- Godot cabinet at `godot/cabinet/` is a **playable, backend-authoritative client**
- Merge conflicts from stashed interactive auth work are resolved
- `dev.ps1` defaults to Godot (`.\dev.ps1` starts API + Godot cabinet)
- The legacy web cabinet is fallback-only and no longer part of the default launcher/build path
- The web cabinet fallback exposes a portrait install shell through
  `src/web/app/manifest.ts` and `src/web/public/icon.svg` so the same cabinet
  surface can be tested as a web/Android-compatible app while Godot remains the
  primary playable client
- Godot cabinet export presets now cover Windows Desktop, Web PWA, and unsigned
  Android APK compatibility lanes from the same portrait `CabinetRoot.tscn`
  client. The project uses GL Compatibility to avoid splitting renderer behavior
  between kiosk, browser, and mobile
- Flutter/mobile clients are removed from the active repo
- Kiosk export lane at `scripts/godot/Build-GodotKiosk.ps1` (requires readiness gate)

## Runtime contract

- `LUCKY5_API_BASE_URL` — backend base URL (default: `http://127.0.0.1:8080`)
- `LUCKY5_ACCESS_TOKEN` — preloaded bearer token (optional; interactive auth fallback)
- `LUCKY5_AUTH_USERNAME` / `LUCKY5_AUTH_PASSWORD` — interactive auth credentials
- `LUCKY5_MACHINE_ID` — machine ID (default: 1)

## Architecture

- Fixture-first boot (`fixture_snapshot.json`) renders immediately, even offline
- HTTP hydration from `GET /api/Game/machine/{machineId}/cabinet-snapshot`
- Idempotent `cabinet.v1` command envelopes for all actions
- Replay recovery via `POST /api/Game/machine/{machineId}/cabinet-replay`
- Interactive auth panel with login, signup, and OTP verification flows
- Server-driven button enablement; Godot never modifies credit totals
- Legacy `v1` snapshots are normalized to `cabinet.v1` at the Godot store boundary
- Mutating Godot commands use one pending action lock with timeout-to-snapshot recovery

## Disposition of prior migration artifacts

- `lucky5-godot-playable-expansion.patch` — superseded by the resolved in-repo code
- `lucky5-godot-playable-expansion-files/` — reference only
- `lucky5-godot-playable-expansion-summary.md` — historical record
- `lucky-5-v-7-godot/` — earlier scratch project, not in use
- `lucky5_godot_deck_v1/` — card asset import package, used by the cabinet
