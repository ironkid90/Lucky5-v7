# Architecture Decision Records

## ADR-001: InMemoryDataStore (no DB yet)

All persistence is volatile dictionaries. Pre-seeded with 3 machines, admin user, hardcoded OTP.
**Status**: Active. Migration to real DB deferred.

## ADR-002: CleanRoom Separation

Authoritative game logic isolated in `Lucky5.Domain/Game/CleanRoom/`. Pure static methods, reducer pattern.
Non-CleanRoom `Game/` is legacy/presentation only.
**Status**: Active. All new game logic must go to CleanRoom.

## ADR-003: Lebanese Paytable Default

`PaytableProfile.Lebanese` pays ALL pairs (MinimumPairRankForPayout = int.MaxValue, threshold unreachable).
**Status**: Active.

## ADR-004: Machine Close at 40M

CloseThreshold = 40,000,000. When credits reach this, IsMachineClosed = true.
Player must cash out to wallet. ResetMachine now clears both ledger and sessions.
**Status**: Active (fixed in session 2026-03-15).

## ADR-005: Double-Up Always Available

No probabilistic gating. Every win gets double-up offer. Card trail tracks history.
**Status**: Active.

## ADR-006: Web-First Priority

Vanilla JS cabinet in wwwroot/ is the original. React/Next.js in src/web/ is active dev target.
Flutter and mobile work deferred until web playable slice complete.
**Status**: Active.
