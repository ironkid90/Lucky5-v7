# Architecture Decisions

## Last Reviewed

2026-03-15

## Core Architecture

- **ADR-001 — Volatile persistence only:** `InMemoryDataStore` remains the active store. Sessions, rounds, ledgers, and profiles are lost on restart. Pre-seeded dev data includes 3 machines, the admin user, and OTP `123456`.
- **ADR-002 — CleanRoom is authoritative:** all new game rules belong in `Lucky5.Domain/Game/CleanRoom/`. The non-CleanRoom `Game/` directory stays legacy/presentation only.
- **ADR-003 — Lebanese paytable is default:** `PaytableProfile.Lebanese` uses `MinimumPairRankForPayout = int.MaxValue`, which means all pairs pay.
- **ADR-004 — Web-first delivery:** the vanilla JS cabinet in `server/src/Lucky5.Api/wwwroot/` is the original implementation; `src/web/` is the active React target. Flutter and Capacitor remain secondary.

## Gameplay / Session Rules

- **ADR-005 — Double-up is always offered on wins:** there is no probabilistic gating on the offer itself.
- **ADR-006 — Machine closes at 40,000,000 credits:** reaching the close threshold sets `IsMachineClosed = true`, blocks new play, and allows forced cash-out.
- **ADR-007 — Machine reset clears close state across sessions:** reset is not just a ledger reset; it also clears `IsMachineClosed` for all sessions on the machine.
- **ADR-008 — 4K jackpot side is captured atomically at deal time:** `GameService.DealAsync()` computes and stores the active Four of a Kind side under the same `LedgerSync` lock that mutates the machine ledger, then copies it into `GameRound.ActiveFourOfAKindSlotAtDeal`. Jackpot payout resolution must use the round snapshot, not the mutable live ledger slot.
