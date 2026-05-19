# Lucky5 Godot Kiosk Release Playbook

This playbook defines the reproducible build, signed asset manifest, kiosk runtime,
deployment, and rollback policy for the Godot cabinet release lane.

The lane is blocked until the production readiness gate passes. Per
`docs/GODOT_MIGRATION_RESET_DEPENDENCY_MAP_2026-05-05.md`, this work item
(`9244d`, kiosk build/signing/deploy/rollback) depends on `055a4` (migration
testing and production readiness gate). Do not build or deploy a production kiosk
package from this lane until readiness evidence is reviewed and approved.

## Invariants

- The backend remains authoritative for credits, wallet balance, machine state,
  active rounds, double-up state, jackpot state, reconnect, and recovery.
- Godot is a presentation client. It must not compute payout, RNG, hand
  evaluation, double-up math, RTP, jackpot settlement, wallet settlement, or other
  game truth.
- No signing keys, Firebase credentials, environment files, production URLs,
  device secrets, or private deployment credentials are committed.
- Generated exports, manifests, signatures, and deployment bundles are local or CI
  artifacts only.

## Required readiness evidence

Before a production build, create a local or CI artifact such as
`tmp/readiness-gate.json` with this minimum shape:

```json
{
  "gate": "godot-production-readiness",
  "approved": true,
  "approved_by": "reviewer-or-change-ticket",
  "approved_at_utc": "2026-05-19T00:00:00Z",
  "evidence": [
    "Godot scene parity and polish accepted",
    "Admin console v1 accepted",
    "Contract/replay/idempotency/auth/parity checks accepted",
    "Godot headless load accepted",
    "Manual QA and burn-in criteria accepted"
  ]
}
```

The helper scripts fail unless `approved` is `true`. Keep this evidence in `tmp/`
or the CI artifact store; it is not source code.

## Toolchain

Use a pinned Godot 4.x executable that matches the project feature line in
`godot/cabinet/project.godot` (`config/features=PackedStringArray("4.6")`). Verify
downloaded Godot binaries with the vendor checksum or signature before use.

Set local environment variables instead of committing machine-specific paths:

```powershell
$env:GODOT_BIN = "C:\Tools\Godot\Godot_v4.6-stable_win64.exe"
$env:LUCKY5_MANIFEST_SIGNING_KEY_PEM_PATH = "C:\Secrets\lucky5-kiosk-manifest-private.pem"
```

The manifest signing key is an RSA private key in PEM format stored outside the
repository. The corresponding public key fingerprint and rotation history should
be recorded in the deployment system or an internal runbook, not in source files
unless the public-key distribution model has been reviewed.

## Reproducible export procedure

1. Confirm the worktree and prerequisite state:

   ```powershell
   git status -sb
   Get-Content tmp/readiness-gate.json | ConvertFrom-Json
   ```

2. Ensure `godot/cabinet/export_presets.cfg` exists locally or is supplied by CI.
   Godot creates this file from the editor export UI. It may contain platform
   paths or signing settings, so review before committing any preset changes.

3. Run the build script from the repository root:

   ```powershell
   .\scripts\godot\Build-GodotKiosk.ps1 `
     -Version "2026.05.19-rc1" `
     -PresetName "Windows Desktop" `
     -ReadinessGatePath "tmp/readiness-gate.json"
   ```

4. The script writes an ignored artifact folder under
   `artifacts/godot-kiosk/<version>/`, exports the Godot package, generates
   `asset-manifest.json`, and writes `asset-manifest.json.sig` when a signing key
   path is provided.

5. Record the produced manifest hash, signature hash, git commit, Godot version,
   and readiness gate artifact ID in the release/change ticket.

## Asset manifest policy

The signed manifest is the kiosk update source of truth.

Rules:

- Include every runtime file in the deployable package, including exported `.exe`,
  `.pck`, DLLs, license files, fonts, images, audio, and approved metadata.
- Exclude only transient logs, signatures generated for the manifest itself, and
  local deployment notes.
- Hash each file with SHA-256 and store slash-normalized relative paths.
- Sort manifest entries by path for deterministic review.
- Sign the manifest JSON, not individual files.
- Rotate signing keys through deployment policy; never commit private keys.
- Kiosk update code must verify the manifest signature before trusting package
  contents and must verify each listed file hash before launching the new build.
- A missing required asset is a deployment blocker, not a reason to fall back to
  procedural placeholders in production.

Manual manifest/signing command for an already-exported folder:

```powershell
.\scripts\godot\New-GodotAssetManifest.ps1 `
  -PackageRoot "artifacts/godot-kiosk/2026.05.19-rc1" `
  -Version "2026.05.19-rc1" `
  -ReadinessGatePath "tmp/readiness-gate.json" `
  -SigningKeyPemPath $env:LUCKY5_MANIFEST_SIGNING_KEY_PEM_PATH
```

## Kiosk runtime notes

- Run on a locked-down OS account with no interactive shell access for players.
- Disable OS sleep, screen savers, and background update restarts during operating
  hours; schedule OS maintenance outside play windows.
- Launch Godot in fullscreen or borderless kiosk mode from the OS supervisor.
- Store runtime configuration outside the exported package and outside source
  control. Prefer environment variables or a machine-local config file with ACLs.
- The client must start in a safe disconnected/recovery state until authenticated,
  joined to a machine, and hydrated from an authoritative backend snapshot.
- On transport failure, disable gameplay commands, show the recovery overlay, then
  re-authenticate, rejoin, and request a full snapshot until replay support is
  proven by the readiness gate.
- Logs must redact tokens, device credentials, player identifiers where possible,
  and any backend secret values. Ship logs through the approved operations channel.
- Keep the web cabinet available as an internal fallback until burn-in explicitly
  approves legacy decommission.

## Deployment procedure

1. Confirm readiness gate approval and release ticket ownership.
2. Build from a clean commit using the command above.
3. Verify `asset-manifest.json` and `asset-manifest.json.sig` exist and are stored
   with the release artifact.
4. Stage the package on the update server or removable installation media.
5. On a non-production kiosk, verify:
   - manifest signature verification succeeds;
   - every file hash matches the manifest;
   - the Godot process launches fullscreen;
   - the client enters recovery when the backend is unavailable;
   - the client hydrates from a backend snapshot before enabling commands.
6. Deploy to one canary kiosk. Monitor startup, connection recovery, snapshot
   hydration, command lock behavior, and backend/admin audit events.
7. Promote to additional kiosks only after canary checks pass and the release
   owner records approval in the change ticket.

## Rollback procedure

1. Keep the last known-good package and signed manifest available on every kiosk
   or in the local update cache before applying an update.
2. If launch, signature, hash, hydration, auth, or recovery checks fail, stop the
   new Godot process and restore the previous package atomically.
3. Clear only the new package staging directory. Do not delete logs or prior
   release evidence.
4. Restart the kiosk supervisor and confirm the previous build reaches the safe
   recovery or live state.
5. Record the failed manifest hash, signature hash, device ID, timestamps, and
   relevant redacted logs in the incident/change ticket.
6. Do not retry a failed build with edited local files. Produce a new versioned
   build from source after the issue is fixed and readiness impact is reviewed.
