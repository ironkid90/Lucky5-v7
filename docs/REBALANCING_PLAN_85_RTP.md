# Lucky5 Game Rebalancing Plan - 85% RTP Target

**Date**: 2026-03-14
**Status**: Proposal for Review
**Target**: 85% RTP with preserved tension, fun, and adrenaline

---

## Executive Summary

This plan proposes a comprehensive rebalancing of the Lucky5 game to achieve a stable 85% RTP while maintaining:
- **Tension**: Sparse hit frequency (24-28%) with meaningful wins
- **Fun**: Unlimited double-up chains with dramatic moments
- **Adrenaline**: Machine-closing runs still happen regularly
- **Core rules**: No changes to Lebanese paytable, Ace auto-win, or Lucky5 switch mechanics

### Current State
- **Measured RTP**: 72.8078% (under target)
- **Base Game**: 65.7957% (scaled)
- **Overlay**: ~7.01% (jackpots + double-up combined)
- **Gap**: Need +12.19 RTP points to reach 85%

### Proposed Distribution
- **Base Game**: 72.50% (scaled with payout controller)
- **Jackpots**: 3.50% (replace-mode progressives)
- **Double-Up**: 9.00% (unlimited chains with soft offer curve)
- **Total**: 85.00%

---

## 1. Core Philosophy

### Design Principles
1. **Keep the Lebanese cabinet identity intact**
   - No pairs payout (sparse hit frequency)
   - Retro feel with meaningful wins
   - Machine-closing fantasy preserved

2. **Use policy and configuration, not rule changes**
   - Payout scale is primary lever
   - Double-up offer curve is secondary lever
   - Deck alteration is tertiary pressure
   - Never change Ace auto-win or Lucky5 mechanics

3. **Maintain excitement curves**
   - Warmup generosity for new sessions
   - Pity systems for losing streaks
   - Cooldowns prevent back-to-back jackpots
   - Progressive tension building

---

## 2. Payout Scale Rebalancing

### 2.1 Current vs Proposed

| Parameter | Current | Proposed | Reason |
|-----------|---------|----------|--------|
| `TargetRtp` | 0.85m | 0.85m | Already correct |
| `TargetDoubleUpRtp` | 0.090m | 0.090m | Already correct |
| `DefaultPayoutScale` | 1.92m | **1.95m** | Lift equilibrium orbit slightly |
| `MinPayoutScale` | 1.18m | **1.25m** | Raise floor for smoother convergence |
| `MaxPayoutScale` | 2.45m | **2.35m** | Lower ceiling to prevent overshoot |
| `MinimumObservedBaseRtp` | 0.3200m | **0.3800m** | Better reflects actual base game |

**Rationale**:
- Current equilibrium should be ~1.87-1.95 based on measured 38.68% base RTP
- Raising default to 1.95 provides slight uplift
- Raising floor prevents excessive cold periods
- Lowering ceiling prevents hot overshoot

### 2.2 Controller Fine-Tuning

| Parameter | Current | Proposed | Reason |
|-----------|---------|----------|--------|
| `ConvergenceHorizon` | 300 | **250** | Faster convergence to target |
| `CorrectionGain` | 1.10m | **1.15m** | Stronger drift correction |
| `MaxCorrection` | 0.35m | **0.30m** | Smoother corrections |
| `DeadZone` | 0.0075m | **0.0100m** | Allow slightly more drift tolerance |
| `JitterAmplitude` | 0.03m | **0.025m** | Reduce variance per round |

**Rationale**:
- Faster convergence (250 vs 300) helps reach target sooner
- Stronger correction gain (1.15 vs 1.10) pulls toward target more aggressively
- Smaller max correction (0.30 vs 0.35) prevents overcorrection swings
- Larger dead zone (1.0% vs 0.75%) reduces micro-corrections
- Lower jitter (2.5% vs 3%) smooths round-to-round variance

### 2.3 Tier Factors

| Tier | Current | Proposed | Reason |
|------|---------|----------|--------|
| `SmallTierFactor` | 0.99m | **1.00m** | No penalty for small wins |
| `MediumTierFactor` | 1.05m | **1.04m** | Slight reduction |
| `BigTierFactor` | 1.12m | **1.08m** | Tighten big-win bonus |

**Rationale**:
- Removing small-tier penalty (0.99-1.00) helps 2-pair/3-of-kind players
- Tightening medium/big bonuses (1.05-1.04, 1.12-1.08) prevents jackpot overshoot
- Narrower spread = more predictable RTP control

### 2.4 Warmup Parameters

| Parameter | Current | Proposed | Reason |
|-----------|---------|----------|--------|
| `WarmupRounds` | 80 | **60** | Faster transition to live control |
| `WarmupOpeningSmallScale` | 1.98m | **2.00m** | Slightly more generous start |
| `WarmupOpeningMediumScale` | 2.05m | **2.08m** | Better first impression |
| `WarmupOpeningBigScale` | 2.15m | **2.15m** | Keep jackpot dream alive early |

**Rationale**:
- 60-round warmup (vs 80) gets to equilibrium faster
- Slightly higher opening scales hook new players
- Big-scale unchanged keeps early jackpot excitement

---

## 3. Double-Up System Rebalancing

### 3.1 Offer Curve Adjustment

**Current Philosophy**: Too suppressive when above target (drops to 8%)
**Proposed Philosophy**: Always keep double-up alive (minimum 15%)

| Drift vs Target | Current Offer | Proposed Offer | Change |
|-----------------|---------------|----------------|--------|
| >= +5.0% (hot) | 8% | **15%** | +7% (keep alive) |
| +2.0% to +5.0% | 15%-8% linear | **20%-15%** linear | +5% band |
| -1.0% to +2.0% (target) | 28% | **30%** | +2% |
| -4.0% to -1.0% | 28%-45% linear | **30%-50%** linear | +2-5% |
| <= -4.0% (cold) | 60% | **65%** | +5% |

**Rationale**:
- Never drop below 15% (vs 8%) keeps the feature visible
- Higher target-band offer (30% vs 28%) improves engagement
- Higher cold-state offer (65% vs 60%) helps recovery
- Maintains unlimited chains and Ace auto-win rules

### 3.2 Configuration Changes

| Parameter | Current | Proposed | Reason |
|-----------|---------|----------|--------|
| `DoubleUpOfferFloor` | 0.08m | **0.15m** | Double-up always available |
| `DoubleUpOfferOverTargetBand` | 0.15m | **0.20m** | More generous when slightly hot |
| `DoubleUpOfferTargetBand` | 0.28m | **0.30m** | Better engagement at equilibrium |
| `DoubleUpOfferRecoveryBand` | 0.45m | **0.50m** | Stronger cold recovery |
| `DoubleUpOfferMax` | 0.60m | **0.65m** | Max recovery boost |

---

## 4. Jackpot System Rebalancing

### 4.1 Current Issues
- Jackpot RTP contribution is inconsistent
- Reset values too high (cause RTP spikes)
- Contributions too aggressive (caps reached too fast)

### 4.2 Proposed Adjustments

| Jackpot | Start (Current) | Start (Proposed) | Cap (Current) | Cap (Proposed) | Contrib (Current) | Contrib (Proposed) |
|---------|-----------------|------------------|---------------|----------------|-------------------|-------------------|
| 4K-A | 160,000 | **140,000** | 1,200,000 | **1,000,000** | 175 | **150** |
| 4K-B | 160,000 | **140,000** | 1,200,000 | **1,000,000** | 175 | **150** |
| Full House | 100,000 | **90,000** | 750,000 | **650,000** | 120 | **110** |
| Straight Flush | 900,000 | **850,000** | 8,500,000 | **7,500,000** | 255 | **240** |
| **Total Contrib** | 725/round | **650/round** | | | | |

**Rationale**:
- Lower start values reduce post-reset RTP spikes
- Lower caps make jackpots hit more frequently (better engagement)
- Lower contributions prevent caps from being reached too quickly
- Total still targets ~3.5% RTP contribution

---

## 5. Streak & Pity System Tuning

### 5.1 Streak Thresholds

| Parameter | Current | Proposed | Reason |
|-----------|---------|----------|--------|
| `StreakSoftThreshold` | 5 | **4** | Activate pity sooner |
| `StreakHardThreshold` | 10 | **8** | Stronger intervention earlier |
| `CrisisThreshold` | 15 | **12** | Emergency boost kicks in faster |
| `CrisisScaleBoost` | 0.05m | **0.07m** | Stronger crisis recovery |
| `MediumWinDroughtThreshold` | 20 | **15** | Address dry spells sooner |

**Rationale**:
- Earlier intervention (4-loss vs 5-loss) improves player satisfaction
- Lower crisis threshold (12 vs 15) prevents extreme frustration
- Stronger crisis boost (7% vs 5%) helps break losing streaks
- Earlier medium-win pity (15 vs 20) maintains engagement

### 5.2 Cooldown System

| Parameter | Current | Proposed | Reason |
|-----------|---------|----------|--------|
| `CooldownLength` | 3 | **2** | Shorter neutral period after big wins |

**Rationale**:
- 2-round cooldown (vs 3) allows faster return to normal play
- Still prevents immediate back-to-back jackpots
- Better balance between protection and flow

---

## 6. Soft Cap & Machine Close

### 6.1 Thresholds

| Parameter | Current | Proposed | Reason |
|-----------|---------|----------|--------|
| `SoftCapWarning` | 24,000,000 | **28,000,000** | More headroom before warnings |
| `SoftCapHard` | 32,000,000 | **35,000,000** | Allow bigger runs |
| `CloseThreshold` | 40,000,000 | **40,000,000** | Keep as-is (already lowered) |

**Rationale**:
- Raising soft caps (24M-28M, 32M-35M) allows more dramatic builds
- Close threshold at 40M is already correct (down from 50M)
- Players can hit meaningful milestones before machine close
- Maintains adrenaline of potential close without hitting it too often

---

## 7. Deck Alteration Policy

### 7.1 Cold Mode

| Parameter | Current | Proposed | Reason |
|-----------|---------|----------|--------|
| `MaxColdRemovals` | 2 | **1** | Less aggressive deck nerfing |
| `MinDeckSize` | 50 | **51** | Maintain more standard deck feel |

**Rationale**:
- Removing only 1 card (vs 2) keeps deck closer to standard
- Minimum 51 cards (vs 50) feels less manipulated
- Rely more on payout scale and less on deck pressure

### 7.2 Hot Mode

| Parameter | Current | Proposed | Reason |
|-----------|---------|----------|--------|
| `MaxHotAdditions` | 2 | **2** | Keep as-is |
| `NeverRemoveFiveOfSpades` | true | **true** | Protect Lucky5 fantasy |

**Rationale**:
- Keep hot additions at 2 for pity mechanisms
- Always protect 5-of-spades to preserve Lucky5 switch fantasy

---

## 8. Implementation Strategy

### Phase 1: Core Parameter Updates
1. Update `EngineConfig` in `CoreModels.cs`
2. Adjust payout scale defaults and bounds
3. Update double-up offer curve parameters
4. Modify jackpot starts, caps, and contributions

### Phase 2: Controller Refinement
1. Update `MachinePolicy.cs` tier factors
2. Adjust warmup parameters and convergence horizon
3. Update streak thresholds and crisis boost
4. Refine cooldown lengths

### Phase 3: Testing & Validation
1. Run simulation with 10k rounds (quick validation)
2. Run simulation with 100k rounds (medium validation)
3. Run simulation with 1M rounds (long-term validation)
4. Measure:
   - Overall RTP convergence
   - Hit frequency (target 24-28%)
   - Machine close frequency (target ~1 in 500-1000 sessions)
   - Double-up engagement (target 30-50% of wins)
   - Jackpot hit frequency (target ~1 in 150-200 rounds)

### Phase 4: Fine-Tuning
1. Analyze simulation results
2. Adjust parameters if needed
3. Iterate until stable 85% RTP achieved
4. Validate player experience metrics

---

## 9. Expected Outcomes

### 9.1 RTP Distribution
- **Base Game**: 72.50% (up 6.70 points from current 65.80%)
- **Jackpots**: 3.50% (current ~2-3%, more consistent)
- **Double-Up**: 9.00% (current ~4%, improved offer curve)
- **Total**: 85.00% +/-0.5% over 100k+ rounds

### 9.2 Player Experience
- **Hit Frequency**: 24-28% (unchanged, sparse Lebanese feel)
- **Medium+ Wins**: 4-6% of rounds (slight increase)
- **Double-Up Engagement**: 30-50% of wins offered (up from current ~20-30%)
- **Machine Closes**: ~1 in 600-800 sessions (dramatic but not too rare)
- **Warmup Feel**: Generous first 60 rounds, smooth transition
- **Streak Recovery**: Faster pity activation, less frustration

### 9.3 Tension & Excitement
- Sparse hits maintain tension
- Meaningful wins when they land
- Unlimited double-up chains preserved
- Ace auto-win preserved
- Lucky5 switch fantasy preserved
- Machine-closing runs still happen
- Adrenaline moments throughout session

---

## 10. Risk Assessment

### Low Risk
- No core rule changes
- All changes are configuration-based
- Easy to revert if needed
- Can iterate quickly

### Medium Risk
- Double-up offer curve changes might over/under-engage
- Jackpot adjustments might affect excitement
- **Mitigation**: Monitor simulation carefully, adjust iteratively

### High Risk
- None identified (all changes are reversible and data-driven)

---

## 11. Success Criteria

### Must Have
1. Total RTP converges to 85% +/-0.5% over 100k rounds
2. Base game contributes ~72.5% (scaled)
3. Jackpots contribute ~3.5%
4. Double-up contributes ~9.0%
5. No core rules changed (Ace, Lucky5, paytable)

### Should Have
1. Hit frequency remains 24-28%
2. Machine closes happen ~1 in 600-800 sessions
3. Warmup feels generous but converges smoothly
4. Pity systems activate appropriately
5. Double-up offered on 30-50% of wins at equilibrium

### Nice to Have
1. Perceived volatility feels medium (not too swingy)
2. Session lengths average 15-25 minutes
3. Comeback moments happen regularly
4. No extreme dry spells (crisis boost effective)

---

## 12. Configuration Summary

### All Proposed Changes in One Place

```csharp
public sealed record EngineConfig(
    // === Payout Scale ===
    decimal TargetRtp = 0.85m,
    decimal TargetDoubleUpRtp = 0.090m,
    decimal MinimumObservedBaseRtp = 0.3800m,
    decimal DefaultPayoutScale = 1.95m,
    decimal MinPayoutScale = 1.25m,
    decimal MaxPayoutScale = 2.35m,
    int WarmupRounds = 60,
    int ConvergenceHorizon = 250,
    decimal CorrectionGain = 1.15m,
    decimal MaxCorrection = 0.30m,
    decimal DeadZone = 0.0100m,
    decimal JitterAmplitude = 0.025m,
    decimal SmallTierFactor = 1.00m,
    decimal MediumTierFactor = 1.04m,
    decimal BigTierFactor = 1.08m,
    decimal WarmupOpeningSmallScale = 2.00m,
    decimal WarmupOpeningMediumScale = 2.08m,
    decimal WarmupOpeningBigScale = 2.15m,

    // === Double-Up Offer Curve ===
    decimal DoubleUpOfferFloor = 0.15m,
    decimal DoubleUpOfferOverTargetBand = 0.20m,
    decimal DoubleUpOfferTargetBand = 0.30m,
    decimal DoubleUpOfferRecoveryBand = 0.50m,
    decimal DoubleUpOfferMax = 0.65m,
    ...

    // === Deck Alteration Bounds ===
    int MaxColdRemovals = 1,
    int MinDeckSize = 51,

    // === Streaks & Pity ===
    int StreakSoftThreshold = 4,
    int StreakHardThreshold = 8,
    int CrisisThreshold = 12,
    decimal CrisisScaleBoost = 0.07m,
    int MediumWinDroughtThreshold = 15,
    int CooldownLength = 2,

    // === Soft Caps ===
    decimal SoftCapWarning = 28_000_000m,
    decimal SoftCapHard = 35_000_000m,
    decimal CloseThreshold = 40_000_000m,

    // === Jackpots (Replace Mode) ===
    decimal JackpotFourOfAKindCap = 1_000_000m,
    decimal JackpotFullHouseCap = 650_000m,
    decimal JackpotStraightFlushCap = 7_500_000m,
    int JackpotFourOfAKindContribution = 150,
    int JackpotFullHouseContribution = 110,
    int JackpotStraightFlushContribution = 240,
    decimal JackpotFourOfAKindStart = 140_000m,
    decimal JackpotFullHouseStart = 90_000m,
    decimal JackpotStraightFlushStart = 850_000m
)
```

**Total Changes**: 31 parameters modified (out of ~45 total)
**Philosophy**: Comprehensive rebalancing while preserving core game identity

---

## Conclusion

This rebalancing plan achieves the 85% RTP target through careful calibration of:
1. **Payout scale convergence** (primary lever)
2. **Double-up offer curve** (engagement lever)
3. **Jackpot economics** (dream layer)
4. **Pity systems** (player satisfaction)
5. **Soft caps** (session management)

All changes preserve the Lebanese cabinet identity:
- No pairs payout
- Unlimited double-up
- Ace auto-win
- Lucky5 switch fantasy
- Machine-closing runs
- Tension and adrenaline

The approach is **data-driven, reversible, and iterative**.
