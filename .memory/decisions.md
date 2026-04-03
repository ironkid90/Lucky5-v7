# Architecture Decisions

## Last Reviewed

## Core Architecture

## Gameplay / Session Rules


- [date-entry] 2026-03-31

- [adr-001-volatile-persistence] **ADR-001 — Volatile persistence only:** `InMemoryDataStore` remains the active store. Sessions, rounds, ledgers, and profiles are lost on restart. Pre-seeded dev data includes 3 machines, the admin user, and OTP `123456`.

- [adr-002-cleanroom-authoritative] **ADR-002 — CleanRoom is authoritative:** all new game rules belong in `Lucky5.Domain/Game/CleanRoom/`. The non-CleanRoom `Game/` directory stays legacy/presentation only.

- [adr-003-lebanese-paytable-default] **ADR-003 — Lebanese paytable is default:** `PaytableProfile.Lebanese` uses `MinimumPairRankForPayout = int.MaxValue`, which means **no single pair pays**; **Two Pair** is the minimum qualifying hand.

- [adr-004-web-first-delivery] **ADR-004 — Web-first delivery:** the vanilla JS cabinet in `server/src/Lucky5.Api/wwwroot/` is the original implementation; `src/web/` is the active React target. Flutter and Capacitor remain secondary.

- [adr-005-double-up-offered] **ADR-005 — Double-up is always offered on wins:** there is no probabilistic gating on the offer itself.

- [adr-006-machine-close-threshold] **ADR-006 — Machine closes at 40,000,000 credits:** reaching the close threshold sets `IsMachineClosed = true`, blocks new play, and allows forced cash-out.

- [adr-007-machine-reset-clears-state] **ADR-007 — Machine reset clears close state across sessions:** reset is not just a ledger reset; it also clears `IsMachineClosed` for all sessions on the machine.

- [adr-008-jackpot-capture-atomic] **ADR-008 — 4K jackpot side is captured atomically at deal time:** `GameService.DealAsync()` computes and stores the active Four of a Kind side under the same `LedgerSync` lock that mutates the machine ledger, then copies it into `GameRound.ActiveFourOfAKindSlotAtDeal`. Jackpot payout resolution must use the round snapshot, not the mutable live ledger slot.

- [adr-009-live-double-up-offering] **ADR-009 — Live double-up offering is unconditional on wins:** the live service path in `GameService.DrawAsync()` currently sets `DoubleUpOffered = payout > 0`, so every paying hand can enter double-up. `MachinePolicy.ShouldOfferDoubleUp()` is not part of the live gameplay path today.

- [adr-010-live-rtp-authority] **ADR-010 — Live RTP authority is code when docs drift:** for current balancing work, treat `GameService`, `MachinePolicy`, `Lucky5DoubleUpEngine`, `MachineLedgerState`, and `EngineConfig` as authoritative over older docs and simulation notes when they disagree.

- [adr-011-balancing-direction] **ADR-011 — Current balancing direction is an 80% middle ground, not harsher scripting:** the previous 85% direction proved difficult to balance cleanly because double-up variance is high under the clean-room rule set. The next pass should preserve visible rules and deterministic pre-shuffled logic, and prefer bounded pre-shuffle control, payout-scale tuning, and jackpot economics over obviously scripted outcomes.

- [adr-012-simulation-live-parity] **ADR-012 — Simulation/live parity must be restored before trusting RTP claims:** current simulation still models policy-based double-up offer gating, while the live service path currently offers double-up on every paying hand. Any future 80% certification run must mirror live gameplay first.

- [adr-013-preserve-visible-rules] **ADR-013 — Preserve visible rules before using RTP levers:** user direction for the 80% pass is to avoid turning the game into obviously scripted gameplay. Prefer lowering the payout-scale orbit, modest jackpot-economics cooling, and tiny pre-shuffle double-up deck envelopes over visible rule changes such as ace-rule changes, Lucky5 changes, chain caps, or aggressive double-up offer suppression.
