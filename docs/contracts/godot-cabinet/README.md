# Lucky5 Godot Cabinet Contracts

This directory is the Phase 0 contract package for the Godot cabinet migration.
It is intentionally independent of backend C# type names and web DOM structure so
Godot can bind to stable JSON contracts instead of server internals.

## Artifacts

- `phase-0-discovery.md` catalogs the current web cabinet, endpoint surface,
  realtime behavior, DTO shapes, reconnect rules, and migration gaps.
- `cabinet-contract-v1.schema.json` defines versioned `CabinetSnapshot`,
  `CabinetEvent`, `CabinetCommand`, and command result envelopes.
- `variant-definition-v1.schema.json` defines the versioned variant governance
  model for Lucky5 Classic and future variants.
- `lucky5-classic.variant.v1.json` is the initial Lucky5 Classic variant record.

## Contract Rules

- `server/src/Lucky5.Api/wwwroot` remains the visual source of truth until Godot
  reproduces and supersedes the cabinet experience.
- The backend remains authoritative for credits, wallet balance, machine state,
  active rounds, double-up state, jackpot state, session visibility, reconnect,
  and recovery.
- Godot clients must not derive game rules from visual assets, HTML, CSS, or C#
  DTO names.
- Cabinet messages use explicit `schema_version`, `state_version`,
  `sequence_number`, `command_id`, `expected_state_version`, and
  `idempotency_key` fields for safe reconnect and retry behavior.
- `heartbeat` and `reconnect_sync` are contract commands, not gameplay rules;
  they exist to preserve session visibility and recovery ordering.
- No payout table, RNG, hand evaluation, double-up math, RTP, or game rule
  change is authorized by these contracts.
