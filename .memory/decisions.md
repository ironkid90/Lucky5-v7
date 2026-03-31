# Architecture Decisions

## Last Reviewed

2026-03-31

## Core Architecture

- **ADR-001 — Volatile persistence only:** `InMemoryDataStore` remains the active store. Sessions, rounds, ledgers, and profiles are lost on restart. Pre-seeded dev data includes 3 machines, the admin user, and OTP `123456`.
- **ADR-002 — CleanRoom is authoritative:** all new game rules belong in `Lucky5.Domain/Game/CleanRoom/`. The non-CleanRoom `Game/` directory stays legacy/presentation only.
- **ADR-003 — Lebanese paytable is default:** `PaytableProfile.Lebanese` uses `MinimumPairRankForPayout = int.MaxValue`, which means **no single pair pays**; **Two Pair** is the minimum qualifying hand.
- **ADR-004 — Web-first delivery:** the vanilla JS cabinet in `server/src/Lucky5.Api/wwwroot/` is the original implementation; `src/web/` is the active React target. Flutter and Capacitor remain secondary.

## Gameplay / Session Rules

- **ADR-005 — Double-up is always offered on wins:** there is no probabilistic gating on the offer itself.
- **ADR-006 — Machine closes at 40,000,000 credits:** reaching the close threshold sets `IsMachineClosed = true`, blocks new play, and allows forced cash-out.
- **ADR-007 — Machine reset clears close state across sessions:** reset is not just a ledger reset; it also clears `IsMachineClosed` for all sessions on the machine.
- **ADR-008 — 4K jackpot side is captured atomically at deal time:** `GameService.DealAsync()` computes and stores the active Four of a Kind side under the same `LedgerSync` lock that mutates the machine ledger, then copies it into `GameRound.ActiveFourOfAKindSlotAtDeal`. Jackpot payout resolution must use the round snapshot, not the mutable live ledger slot.
- **ADR-009 — Live double-up offering is unconditional on wins:** the live service path in `GameService.DrawAsync()` currently sets `DoubleUpOffered = payout > 0`, so every paying hand can enter double-up. `MachinePolicy.ShouldOfferDoubleUp()` is not part of the live gameplay path today.
- **ADR-010 — Live RTP authority is code when docs drift:** for current balancing work, treat `GameService`, `MachinePolicy`, `Lucky5DoubleUpEngine`, `MachineLedgerState`, and `EngineConfig` as authoritative over older docs and simulation notes when they disagree.
- **ADR-011 — Current balancing direction is an 80% middle ground, not harsher scripting:** the previous 85% direction proved difficult to balance cleanly because double-up variance is high under the clean-room rule set. The next pass should preserve visible rules and deterministic pre-shuffled logic, and prefer bounded pre-shuffle control, payout-scale tuning, and jackpot economics over obviously scripted outcomes.
- **ADR-012 — Simulation/live parity must be restored before trusting RTP claims:** current simulation still models policy-based double-up offer gating, while the live service path currently offers double-up on every paying hand. Any future 80% certification run must mirror live gameplay first.
- **ADR-013 — Preserve visible rules before using RTP levers:** user direction for the 80% pass is to avoid turning the game into obviously scripted gameplay. Prefer lowering the payout-scale orbit, modest jackpot-economics cooling, and tiny pre-shuffle double-up deck envelopes over visible rule changes such as ace-rule changes, Lucky5 changes, chain caps, or aggressive double-up offer suppression.
