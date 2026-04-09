# Lucky5 Arcade-Grade Persistence Upgrade (Draft PR)

## Objective

Replace fragile snapshot-based persistence with deterministic aggregate-based architecture.

## Key Changes

- Introduced MachineSessionAggregate (aggregate root)
- Introduced repository abstraction for Redis-backed persistence
- Introduced system integrity validator (fail-fast startup)

## Next Steps (Required for full cutover)

1. Replace GameService store access with aggregate repository
2. Implement Redis atomic writes (Lua script)
3. Introduce deterministic reconstruction engine on startup
4. Replace DoubleUp DTO with explicit deterministic contract
5. Add Playwright runtime verification using render_game_to_text()

## Status

This PR establishes the foundation layer required for a full migration.

Follow-up PRs will:
- remove snapshot persistence
- enforce single render path
- introduce full state machine guards
