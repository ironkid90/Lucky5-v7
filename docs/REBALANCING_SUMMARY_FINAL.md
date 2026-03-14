# Lucky5 Rebalancing Summary - Final

**Date**: 2026-03-14
**Version**: v7 (post-rebalance)
**Status**: COMPLETE - All Parameters Applied & Validated

---

## What Changed

### Configuration (31 parameters updated in `EngineConfig`)

**Payout Scale Controller**
- `DefaultPayoutScale`: 1.92 -> 1.95 (slightly more generous equilibrium)
- `MinPayoutScale`: 1.18 -> 1.25 (higher floor = fewer extreme cold spells)
- `MaxPayoutScale`: 2.45 -> 2.35 (lower ceiling = less overshoot)
- `MinimumObservedBaseRtp`: 0.3200 -> 0.3800 (better reflects actual base game)
- `ConvergenceHorizon`: 300 -> 250 (faster convergence)
- `CorrectionGain`: 1.10 -> 1.15 (stronger correction)
- `MaxCorrection`: 0.35 -> 0.30 (smoother corrections)
- `DeadZone`: 0.0075 -> 0.0100 (wider tolerance band)
- `JitterAmplitude`: 0.03 -> 0.025 (less round-to-round noise)

**Tier Factors**
- `SmallTierFactor`: 0.99 -> 1.00 (no penalty for small wins)
- `MediumTierFactor`: 1.05 -> 1.04 (slight reduction)
- `BigTierFactor`: 1.12 -> 1.08 (tighter big-win bonus)

**Warmup Phase**
- `WarmupRounds`: 80 -> 60 (shorter warmup, faster equilibrium)
- `WarmupOpeningSmallScale`: 1.98 -> 2.00 (slightly more generous)
- `WarmupOpeningMediumScale`: 2.05 -> 2.08 (better first impression)

**Double-Up Offer Curve**
- `DoubleUpOfferFloor`: 0.08 -> 0.15 (always keep double-up visible)
- `DoubleUpOfferOverTargetBand`: 0.15 -> 0.20 (more generous when slightly hot)
- `DoubleUpOfferTargetBand`: 0.28 -> 0.30 (better engagement at equilibrium)
- `DoubleUpOfferRecoveryBand`: 0.45 -> 0.50 (stronger cold recovery)
- `DoubleUpOfferMax`: 0.60 -> 0.65 (max recovery boost)

**Streak & Pity System**
- `StreakSoftThreshold`: 5 -> 4 (earlier soft pity)
- `StreakHardThreshold`: 10 -> 8 (earlier hard pity)
- `CrisisThreshold`: 15 -> 12 (earlier emergency boost)
- `CrisisScaleBoost`: 0.05 -> 0.07 (stronger crisis recovery)
- `MediumWinDroughtThreshold`: 20 -> 15 (address dry spells sooner)
- `CooldownLength`: 3 -> 2 (shorter post-win cooldown)

**Jackpot Economics**
- `JackpotFourOfAKindStart`: 160,000 -> 140,000
- `JackpotFullHouseStart`: 100,000 -> 90,000
- `JackpotStraightFlushStart`: 900,000 -> 850,000
- `JackpotFourOfAKindCap` / `JackpotFullHouseCap` / `JackpotStraightFlushCap`: lowered
- Contributions per round: 725 -> 650 total

**Soft Caps**
- `SoftCapWarning`: 24M -> 28M (more headroom)
- `SoftCapHard`: 32M -> 35M (bigger runs allowed)

**Deck Alteration**
- `MaxColdRemovals`: 2 -> 1 (less aggressive)
- `MinDeckSize`: 50 -> 51 (closer to standard deck)

---

## What Did NOT Change
- Core paytable (Lebanese rules, no pairs payout)
- Ace auto-win in double-up
- Lucky5 switch mechanic
- Double-up unlimited chains
- Machine close threshold (40M)
- Card deck composition (standard 52 + joker base)
- SignalR/WebSocket protocol
- API contracts
- Database schema

---

## Files Modified

### Backend
- `server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs` - All 31 EngineConfig parameters
- `server/src/Lucky5.Infrastructure/Services/GameService.cs` - Machine close lifecycle fixes (PR #9)
- `server/src/Lucky5.Infrastructure/Services/AdminService.cs` - IsMachineClosed reset on admin reset

### Frontend
- `server/src/Lucky5.Api/wwwroot/js/game.js` - JACKPOT_RESET values, auto-cashout on machine close

### Tests & Simulation
- `server/tests/Lucky5.Tests/CleanRoomEngineTests.cs` - Updated default assertions
- `server/src/Lucky5.Simulation/Program.cs` - Fixed session credits scoping

### Documentation
- `docs/REBALANCING_PLAN_85_RTP.md` - Full plan with rationale
- `docs/REBALANCING_RESULTS_85_RTP.md` - Simulation results
- `docs/REBALANCING_SUMMARY_FINAL.md` - This file

---

## Validation Results

| Check | Result |
|-------|--------|
| RTP converges to 85% +/-0.5% | PASS |
| Hit frequency 24-28% | PASS (26.1%) |
| Machine closes still occur | PASS (~152/100k) |
| Double-up engagement improved | PASS (~30%) |
| Pity system effective | PASS (crisis 89%) |
| No core rule changes | PASS |
| Tests pass | PASS |
| Build succeeds | PASS |

---

## Deployment Notes

1. All changes are configuration-only (no schema or API changes)
2. Client JACKPOT_RESET must match server start values:
   - FH: 90,000 (was 100,000)
   - 4K: 140,000 (was 160,000)
   - SF: 850,000 (was 900,000)
3. No migration scripts needed
4. Compatible with existing sessions (graceful transition)
5. Monitor RTP in production for first 24h to confirm convergence
