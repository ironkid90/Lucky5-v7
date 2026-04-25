# Godot cabinet migration starter slice

This slice starts the Lucky5 cabinet migration without changing backend game authority.

## What is in this slice

- `contracts/cabinet/cabinet-v1.schema.json`
  - versioned `CabinetSnapshot`, `CabinetEvent`, `CabinetCommand`, and `VariantDefinition` contracts
- `server/src/Lucky5.Application/Dtos/CabinetContractsDto.cs`
  - backend DTO symbols matching the migration boundary
- `GET /api/Game/machine/{machineId}/cabinet-snapshot`
  - read-only backend snapshot endpoint for the Godot cabinet contract
- `godot/cabinet/`
  - a Godot 4 portrait cabinet prototype that renders a static Lucky5 Classic fixture

## Current scope

- presentation-only Godot prototype
- no payout, RNG, jackpot, or wallet logic in Godot
- static Godot fixture load, with backend snapshot hydration ready for the next client wiring step
- contract-first path toward future idempotent command endpoints

## Visual target captured in the prototype

- 720x1280 portrait cabinet
- rainbow paytable pinned top-left
- credit and stake block pinned top-right
- centered five-card row
- jackpot identity block above the wooden control deck
- Lebanese button color order: HOLD amber, DEAL/DRAW red, BET green

## Suggested next backend steps

1. Add explicit `state_version` ownership and idempotency keys on deal/draw/double-up commands.
2. Promote variant data into a canonical backend `VariantDefinition`.
3. Wire SignalR event payloads to the new cabinet event schema.

## Suggested next Godot steps

1. Replace fixture loading with HTTP snapshot hydration.
2. Add reconnect overlay and sequence-gap recovery.
3. Map live button enablement to authoritative backend state.
4. Add sound, card flip timing, and jackpot highlight polish using the existing pacing docs.
