# Lucky5 6-Phase RTP Recalibration (85% -> 80%)

Date: 2026-04-08
Status: Implementation update / production-ready design spec
Scope: Deterministic CleanRoom core only

---

## 1. Purpose

This document translates the current Lucky5 80% direction into a concrete, file-oriented implementation plan for the existing C# deterministic core.

It is intentionally a controlled evolution of the current architecture:

- `EngineConfig` remains the primary configuration surface
- `MachinePolicy` remains the main RTP control loop
- all control stays pre-shuffle and deterministic
- frontend remains display-only and backend-authoritative
- Lebanese paytable, Ace auto-win, Lucky 5 switch-only, and uncapped double-up remain preserved

This spec replaces vague balancing language with explicit pseudocode, bounded formulas, DTO schemas, and simulation requirements that are safe to implement in the current repo.

---

## 2. Non-Negotiable Constraints

The implementation MUST preserve:

1. Lebanese paytable exactly as shipped
2. Two Pair minimum qualifying hand
3. Ace auto-win in double-up
4. Lucky 5 switch-only activation, 4x first / 2x repeat
5. deterministic pre-shuffled outcome logic
6. backend authority over state, balance, jackpots, and double-up outcomes
7. machine close at 40,000,000 credits

The recalibration MUST NOT use:

- post-choice outcome rigging
- direct hand forcing
- raw-result overrides after shuffle
- visible rule suppression as the primary RTP lever

---

## 3. File Ownership Map

### 3.1 Primary files to change

- `server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs`
- `server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs`
- `server/src/Lucky5.Application/Dtos/MachineSessionDto.cs`
- `server/src/Lucky5.Application/Dtos/` (new transparency DTO)
- `server/src/Lucky5.Infrastructure/Services/GameService.cs`
- `server/src/Lucky5.Simulation/Program.cs`
- `server/tests/Lucky5.Tests/` (new regression and simulation-gate assertions)

### 3.2 Code ownership rule

- mathematical control logic belongs in `CleanRoom/`
- service assembly is allowed only to map state, expose DTOs, and log/audit policy outputs
- simulation must mirror live service path, not a simplified approximation

---

## 4. Phase Overview

### Phase 1 - Config shift
Lower the controller from the current 85% regime to an 80% regime by changing only bounded configuration and target allocation.

### Phase 2 - Controller stabilization
Reduce overshoot, small-sample volatility, and policy oscillation with wider dead-zone behavior, slower convergence, and bounded correction.

### Phase 3 - Transparency layer
Expose regulator-safe policy state to the frontend without leaking internal manipulation details.

### Phase 4 - Pity / warmup rebalance
Keep warmup and pity present, but mathematically bounded and auditable for long-run neutrality.

### Phase 5 - Overlay guardrails
Prevent jackpots and double-up from becoming RTP leak paths by feeding overlay pressure back into future distribution control only.

### Phase 6 - Deterministic certification harness
Add a 500,000-round SplitMix64 harness that verifies convergence, volatility windows, and neutrality of phase mechanics.

---

## 5. RTP Budget Direction

Recommended working 80% budget for the first code pass:

- Base scaled RTP: 67.75%
- Jackpot RTP: 2.75%
- Double-up RTP: 9.50%
- Total RTP: 80.00%

This preserves double-up as the excitement layer while moving most control burden back to the base controller.

```text
TargetRtp             = 0.8000
TargetJackpotRtp      = 0.0275
TargetDoubleUpRtp     = 0.0950
TargetScaledBaseRtp   = 0.8000 - 0.0275 - 0.0950 = 0.6775
```

---

## 6. EngineConfig - Proposed 80% Control Surface

### 6.1 Production-ready parameter set

```csharp
public sealed record EngineConfig(
    // === Core targets ===
    decimal TargetRtp = 0.80m,
    decimal TargetJackpotRtp = 0.0275m,
    decimal TargetDoubleUpRtp = 0.0950m,
    decimal MinimumObservedBaseRtp = 0.3800m,

    // === Scale orbit ===
    decimal DefaultPayoutScale = 1.75m,
    decimal MinPayoutScale = 1.18m,
    decimal MaxPayoutScale = 2.05m,

    // === Low-sample stability ===
    int ConvergenceHorizon = 320,
    decimal CorrectionGain = 1.00m,
    decimal MaxCorrection = 0.22m,
    decimal DeadZone = 0.0125m,
    decimal JitterAmplitude = 0.015m,
    int DriftSmoothingWindow = 120,
    int MinimumRoundsBeforeFullCorrection = 80,

    // === Tier spread ===
    decimal SmallTierFactor = 1.00m,
    decimal MediumTierFactor = 1.03m,
    decimal BigTierFactor = 1.06m,

    // === Warmup ===
    int WarmupRounds = 50,
    decimal WarmupOpeningSmallScale = 1.90m,
    decimal WarmupOpeningMediumScale = 1.96m,
    decimal WarmupOpeningBigScale = 2.02m,
    decimal WarmupFloorBlend = 0.15m,

    // === Pity / crisis ===
    int StreakSoftThreshold = 4,
    int StreakHardThreshold = 8,
    int CrisisThreshold = 12,
    decimal SoftPityScaleBoost = 0.020m,
    decimal HardPityScaleBoost = 0.040m,
    decimal CrisisScaleBoost = 0.055m,
    decimal PityBoostCap = 0.070m,
    int MediumWinDroughtThreshold = 15,
    int CooldownLength = 2,

    // === Envelope control ===
    decimal EnvelopeScaleClamp = 0.10m,
    decimal RollingMeanScaleAlpha = 0.08m,
    decimal HouseEdgeBuffer = 0.010m,
    decimal HouseEdgeBufferCap = 0.015m,

    // === Jackpot guardrails ===
    decimal JackpotRtpSoftCap = 0.030m,
    decimal JackpotRtpHardCap = 0.033m,
    decimal JackpotLeakDamp = 0.50m,

    // === Double-up guardrails ===
    decimal DoubleUpRtpSoftCap = 0.100m,
    decimal DoubleUpRtpHardCap = 0.105m,
    decimal DoubleUpLeakDamp = 0.65m,

    // === Double-up envelope shaping ===
    int RecoveryDuAceAdds = 1,
    int RecoveryDuLucky5Adds = 1,
    int PressureDuAceRemovals = 1,
    int PressureDuNeutralBadAdds = 1,

    // === Session thresholds ===
    decimal SoftCapWarning = 28_000_000m,
    decimal SoftCapHard = 35_000_000m,
    decimal CloseThreshold = 40_000_000m,

    // === Jackpots ===
    decimal JackpotFourOfAKindCap = 900_000m,
    decimal JackpotFullHouseCap = 575_000m,
    decimal JackpotStraightFlushCap = 6_800_000m,
    int JackpotFourOfAKindContribution = 140,
    int JackpotFullHouseContribution = 100,
    int JackpotStraightFlushContribution = 220,
    decimal JackpotFourOfAKindStart = 120_000m,
    decimal JackpotFullHouseStart = 80_000m,
    decimal JackpotStraightFlushStart = 750_000m
);
```

### 6.2 New EngineConfig helpers

```csharp
public decimal TargetScaledBaseRtp => TargetRtp - TargetJackpotRtp - TargetDoubleUpRtp;

public decimal BoundedHouseEdgeBuffer
    => decimal.Clamp(HouseEdgeBuffer, 0m, HouseEdgeBufferCap);
```

### 6.3 Rationale

- Lower orbit than the 85% build
- tighter jitter
- slower correction response
- additive but capped pity system
- overlay caps become explicit instead of implicit
- house-edge buffer is bounded and non-outcome-forcing

---

## 7. MachinePolicy State Extensions

### 7.1 Extend MachinePolicyState

```csharp
public sealed class MachinePolicyState
{
    public decimal CreditsIn { get; set; }
    public decimal CreditsOut { get; set; }
    public decimal BaseCreditsOut { get; set; }
    public decimal JackpotCreditsOut { get; set; }
    public decimal DoubleUpCreditsOut { get; set; }
    public decimal TargetRtp { get; set; }
    public int RoundCount { get; set; }
    public int ConsecutiveLosses { get; set; }
    public int RoundsSinceMediumWin { get; set; }
    public int CooldownRoundsRemaining { get; set; }
    public decimal NetSinceLastClose { get; set; }
    public int RoundsSinceLucky5Hit { get; set; }

    // === New policy telemetry ===
    public decimal SmoothedObservedRtp { get; set; }
    public decimal SmoothedBaseRtp { get; set; }
    public decimal RollingMeanScale { get; set; }
    public int SessionRounds { get; set; }
    public int MediumWinDroughtRounds { get; set; }

    public decimal ObservedRtp => CreditsIn <= 0m ? TargetRtp : decimal.Round(CreditsOut / CreditsIn, 4);
    public decimal BaseRtp => CreditsIn <= 0m ? 0m : decimal.Round(BaseCreditsOut / CreditsIn, 4);
    public decimal JackpotRtp => CreditsIn <= 0m ? 0m : decimal.Round(JackpotCreditsOut / CreditsIn, 4);
    public decimal DoubleUpRtp => CreditsIn <= 0m ? 0m : decimal.Round(DoubleUpCreditsOut / CreditsIn, 4);
    public decimal Drift => ObservedRtp - TargetRtp;
}
```

---

## 8. Policy Output Contracts

```csharp
public enum PolicyEnvelopeMode
{
    Recovery = 0,
    Neutral = 1,
    Celebrate = 2,
    Cooldown = 3,
    Pressure = 4
}

public sealed record PolicyTransparency(
    bool IsWarmupActive,
    bool IsPityActive,
    bool IsCrisisActive,
    PolicyEnvelopeMode EnvelopeMode,
    decimal CurrentScale,
    decimal BaseScale,
    decimal WarmupBias,
    decimal PityBoost,
    decimal CorrectionGainAdjustment,
    decimal HouseEdgeBufferApplied,
    int SessionRounds,
    int ConsecutiveLosses,
    int MediumWinDroughtRounds);

public sealed record PolicyResolution(
    decimal RawScale,
    decimal SmallScale,
    decimal MediumScale,
    decimal BigScale,
    PolicyEnvelopeMode EnvelopeMode,
    PolicyTransparency Transparency);
```

---

## 9. Scale Mathematics

### 9.1 Definitions

```text
TargetScaledBaseRtp = TargetRtp - TargetJackpotRtp - TargetDoubleUpRtp
ObservedBaseRtp     = max(SmoothedBaseRtp, MinimumObservedBaseRtp)
Drift               = SmoothedObservedRtp - TargetRtp
EquilibriumScale    = TargetScaledBaseRtp / ObservedBaseRtp
```

### 9.2 BaseScale

`BaseScale` is the equilibrium orbit before warmup, pity, and bounded correction.

```text
BaseScale = clamp(EquilibriumScale, MinPayoutScale, MaxPayoutScale)
```

### 9.3 CorrectionGainAdjustment

This is the bounded drift correction term. It is zero inside the dead zone, fades in gradually before full correction, and is capped.

```text
RampFactor = clamp(SessionRounds / ConvergenceHorizon, 0.0, 1.0)

if abs(Drift) <= DeadZone:
    CorrectionGainAdjustment = 0
else:
    CorrectionGainAdjustment = clamp(
        -Drift * CorrectionGain * RampFactor,
        -MaxCorrection,
        +MaxCorrection)
```

### 9.4 WarmupBias

Warmup must be front-loaded but smoothly decaying toward the live controller.

```text
WarmupRatio = 1.0 - clamp(SessionRounds / WarmupRounds, 0.0, 1.0)

WarmupOpeningScale =
    Small tier  -> WarmupOpeningSmallScale
    Medium tier -> WarmupOpeningMediumScale
    Big tier    -> WarmupOpeningBigScale

WarmupBias =
    if SessionRounds >= WarmupRounds:
        0
    else:
        (WarmupOpeningScale - BaseScale) * WarmupRatio
```

### 9.5 PityBoost

Pity is additive, capped, and only depends on bounded streak/drought state.

```text
SoftPity  = ConsecutiveLosses >= StreakSoftThreshold ? SoftPityScaleBoost : 0
HardPity  = ConsecutiveLosses >= StreakHardThreshold ? HardPityScaleBoost : 0
CrisisPity = ConsecutiveLosses >= CrisisThreshold ? CrisisScaleBoost : 0
DroughtPity = MediumWinDroughtRounds >= MediumWinDroughtThreshold ? SoftPityScaleBoost : 0

PityBoost = clamp(
    SoftPity + HardPity + CrisisPity + DroughtPity,
    0,
    PityBoostCap)
```

### 9.6 HouseEdgeBuffer

HouseEdgeBuffer is NOT an outcome override. It only shifts envelope selection and deck-pressure probability.

```text
BoundedHouseEdgeBuffer = clamp(HouseEdgeBuffer, 0.0, HouseEdgeBufferCap)
AdjustedTargetRtpForEnvelope = TargetRtp - BoundedHouseEdgeBuffer
```

Allowed uses:

- selecting `Recovery` / `Neutral` / `Pressure` envelopes
- choosing tiny pre-shuffle deck envelopes
- reducing the likelihood of generosity when already near target

Forbidden uses:

- replacing already shuffled results
- editing resolved hands
- raw payout override after hand resolution
- forced win / forced loss logic

### 9.7 Final raw scale

```text
RawScale = BaseScale + CorrectionGainAdjustment + WarmupBias + PityBoost
```

### 9.8 EnvelopeClamp

The controller must remain close to its rolling orbit to prevent visible swinging.

```text
ClampedRawScale = clamp(
    RawScale,
    RollingMeanScale - EnvelopeScaleClamp,
    RollingMeanScale + EnvelopeScaleClamp)
```

### 9.9 Tiered scales

```text
SmallScale  = clamp(ClampedRawScale * SmallTierFactor,  MinPayoutScale, MaxPayoutScale)
MediumScale = clamp(ClampedRawScale * MediumTierFactor, MinPayoutScale, MaxPayoutScale)
BigScale    = clamp(ClampedRawScale * BigTierFactor,    MinPayoutScale, MaxPayoutScale)
```

---

## 10. MachinePolicy Resolution Loop

### 10.1 New top-level entry point

```csharp
public static PolicyResolution ResolvePolicy(MachinePolicyState state, EngineConfig cfg, ulong seed)
{
    var smoothedObservedRtp = SmoothObservedRtp(state, cfg);
    var smoothedBaseRtp = SmoothBaseRtp(state, cfg);
    var effectiveBaseRtp = decimal.Max(smoothedBaseRtp, cfg.MinimumObservedBaseRtp);

    var targetScaledBaseRtp = cfg.TargetScaledBaseRtp;
    var equilibriumScale = targetScaledBaseRtp / effectiveBaseRtp;
    var baseScale = decimal.Clamp(equilibriumScale, cfg.MinPayoutScale, cfg.MaxPayoutScale);

    var drift = smoothedObservedRtp - cfg.TargetRtp;
    var correction = ResolveCorrectionGainAdjustment(drift, state.SessionRounds, cfg);
    var pityBoost = ResolvePityBoost(state, cfg);
    var envelopeMode = ResolveEnvelopeMode(state, drift, cfg);

    var rawScale = baseScale + correction + pityBoost;
    rawScale = ApplyOverlayLeakDamp(rawScale, state, cfg);
    rawScale = ApplyWarmupBias(rawScale, baseScale, envelopeMode, state.SessionRounds, cfg);
    rawScale = ApplyJitter(rawScale, seed, cfg);
    rawScale = ApplyEnvelopeClamp(rawScale, state.RollingMeanScale, cfg);

    var smallScale = decimal.Clamp(rawScale * cfg.SmallTierFactor, cfg.MinPayoutScale, cfg.MaxPayoutScale);
    var mediumScale = decimal.Clamp(rawScale * cfg.MediumTierFactor, cfg.MinPayoutScale, cfg.MaxPayoutScale);
    var bigScale = decimal.Clamp(rawScale * cfg.BigTierFactor, cfg.MinPayoutScale, cfg.MaxPayoutScale);

    var transparency = new PolicyTransparency(
        IsWarmupActive: state.SessionRounds < cfg.WarmupRounds,
        IsPityActive: pityBoost > 0m,
        IsCrisisActive: state.ConsecutiveLosses >= cfg.CrisisThreshold,
        EnvelopeMode: envelopeMode,
        CurrentScale: rawScale,
        BaseScale: baseScale,
        WarmupBias: ResolveWarmupBiasValue(baseScale, envelopeMode, state.SessionRounds, cfg),
        PityBoost: pityBoost,
        CorrectionGainAdjustment: correction,
        HouseEdgeBufferApplied: cfg.BoundedHouseEdgeBuffer,
        SessionRounds: state.SessionRounds,
        ConsecutiveLosses: state.ConsecutiveLosses,
        MediumWinDroughtRounds: state.MediumWinDroughtRounds);

    return new PolicyResolution(rawScale, smallScale, mediumScale, bigScale, envelopeMode, transparency);
}
```

### 10.2 Envelope mode selection

```csharp
private static PolicyEnvelopeMode ResolveEnvelopeMode(MachinePolicyState state, decimal drift, EngineConfig cfg)
{
    var targetForEnvelope = cfg.TargetRtp - cfg.BoundedHouseEdgeBuffer;
    var envelopeDrift = state.SmoothedObservedRtp - targetForEnvelope;

    if (state.CooldownRoundsRemaining > 0)
        return PolicyEnvelopeMode.Cooldown;

    if (state.ConsecutiveLosses >= cfg.CrisisThreshold || state.MediumWinDroughtRounds >= cfg.MediumWinDroughtThreshold)
        return PolicyEnvelopeMode.Recovery;

    if (envelopeDrift >= 0.030m)
        return PolicyEnvelopeMode.Pressure;

    if (envelopeDrift <= -0.025m)
        return PolicyEnvelopeMode.Recovery;

    if (state.RoundCount > 0 && state.RoundCount % 75 == 0 && envelopeDrift < 0m)
        return PolicyEnvelopeMode.Celebrate;

    return PolicyEnvelopeMode.Neutral;
}
```

### 10.3 Correction resolver

```csharp
private static decimal ResolveCorrectionGainAdjustment(decimal drift, int sessionRounds, EngineConfig cfg)
{
    if (decimal.Abs(drift) <= cfg.DeadZone)
        return 0m;

    var ramp = decimal.Clamp((decimal)sessionRounds / cfg.ConvergenceHorizon, 0m, 1m);
    var correction = -drift * cfg.CorrectionGain * ramp;
    return decimal.Clamp(correction, -cfg.MaxCorrection, cfg.MaxCorrection);
}
```

### 10.4 Overlay damp application

```csharp
private static decimal ApplyOverlayLeakDamp(decimal rawScale, MachinePolicyState state, EngineConfig cfg)
{
    var adjusted = rawScale;

    if (state.JackpotRtp > cfg.JackpotRtpSoftCap)
    {
        var jackpotOverflow = state.JackpotRtp - cfg.JackpotRtpSoftCap;
        adjusted -= jackpotOverflow * cfg.JackpotLeakDamp;
    }

    if (state.DoubleUpRtp > cfg.DoubleUpRtpSoftCap)
    {
        var duOverflow = state.DoubleUpRtp - cfg.DoubleUpRtpSoftCap;
        adjusted -= duOverflow * cfg.DoubleUpLeakDamp;
    }

    return adjusted;
}
```

### 10.5 Warmup application

```csharp
private static decimal ApplyWarmupBias(decimal rawScale, decimal baseScale, PolicyEnvelopeMode mode, int sessionRounds, EngineConfig cfg)
{
    if (sessionRounds >= cfg.WarmupRounds)
        return rawScale;

    var openingScale = mode switch
    {
        PolicyEnvelopeMode.Recovery => cfg.WarmupOpeningMediumScale,
        PolicyEnvelopeMode.Celebrate => cfg.WarmupOpeningBigScale,
        _ => cfg.WarmupOpeningSmallScale
    };

    var ratio = 1m - decimal.Clamp((decimal)sessionRounds / cfg.WarmupRounds, 0m, 1m);
    var bias = (openingScale - baseScale) * ratio;
    return rawScale + bias;
}
```

### 10.6 Rolling mean update

```csharp
private static decimal UpdateRollingMeanScale(decimal previousRollingMean, decimal currentScale, EngineConfig cfg)
{
    return previousRollingMean <= 0m
        ? currentScale
        : previousRollingMean + ((currentScale - previousRollingMean) * cfg.RollingMeanScaleAlpha);
}
```

---

## 11. Transparency Layer

### 11.1 Backend DTO schema

Create `server/src/Lucky5.Application/Dtos/MachineTransparencyDto.cs`:

```csharp
namespace Lucky5.Application.Dtos;

public sealed record MachineTransparencyDto(
    bool IsWarmupActive,
    bool IsPityActive,
    bool IsCrisisActive,
    string EnvelopeMode,
    decimal CurrentScale,
    decimal BaseScale,
    decimal WarmupBias,
    decimal PityBoost,
    decimal CorrectionGainAdjustment,
    decimal HouseEdgeBufferApplied,
    int SessionRounds,
    int ConsecutiveLosses,
    int MediumWinDroughtRounds);
```

### 11.2 Session DTO integration

Add to `MachineSessionDto`:

```csharp
public sealed record MachineSessionDto(
    Guid SessionId,
    int MachineId,
    decimal MachineCredits,
    decimal TotalCashIn,
    decimal CashOutThreshold,
    bool CanCashOut,
    bool IsMachineClosed,
    decimal WalletBalance,
    MachineTransparencyDto? Transparency);
```

### 11.3 Active round / draw result optional exposure

Do not expose full transparency on every gameplay response by default.

Recommended:

- required on machine session endpoint
- optional on active-round restore endpoint
- not required on every draw or double-up response unless regulator mode is enabled

### 11.4 Mapping rules in GameService

```csharp
private static MachineTransparencyDto? MapTransparency(PolicyTransparency? t)
{
    if (t is null) return null;

    return new MachineTransparencyDto(
        IsWarmupActive: t.IsWarmupActive,
        IsPityActive: t.IsPityActive,
        IsCrisisActive: t.IsCrisisActive,
        EnvelopeMode: t.EnvelopeMode.ToString(),
        CurrentScale: decimal.Round(t.CurrentScale, 4),
        BaseScale: decimal.Round(t.BaseScale, 4),
        WarmupBias: decimal.Round(t.WarmupBias, 4),
        PityBoost: decimal.Round(t.PityBoost, 4),
        CorrectionGainAdjustment: decimal.Round(t.CorrectionGainAdjustment, 4),
        HouseEdgeBufferApplied: decimal.Round(t.HouseEdgeBufferApplied, 4),
        SessionRounds: t.SessionRounds,
        ConsecutiveLosses: t.ConsecutiveLosses,
        MediumWinDroughtRounds: t.MediumWinDroughtRounds);
}
```

### 11.5 Frontend / regulatory behavior

#### Display contract

- `IsWarmupActive = true` -> show soft non-intrusive indicator such as `WARMUP ACTIVE`
- `IsPityActive = true` -> show `RECOVERY ACTIVE`
- `IsCrisisActive = true` -> show stronger `RECOVERY BOOST` or internal admin tag
- `EnvelopeMode` should be hidden in retail UI and visible only under debug / regulator / admin view

#### Compliance principles

Allowed disclosure:
- current protective session state
- warmup / recovery indicators
- machine phase labels

Do not disclose:
- per-card manipulation terms
- exact deck-envelope composition
- predictive phrasing like "next hand improved"

---

## 12. HouseEdgeBuffer Integrity

### 12.1 Formal rule

`HouseEdgeBuffer` MUST only modify policy selection probabilities and pressure envelopes.

It MUST NOT:

- mutate resolved cards
- bypass `FiveCardDrawEngine`
- bypass `Lucky5DoubleUpEngine`
- change payout after hand evaluation

### 12.2 Mathematical bound

```text
0.0000 <= HouseEdgeBuffer <= 0.0150
Recommended initial value = 0.0100
```

### 12.3 Approved uses

- move envelope mode from `Neutral` to `Pressure` slightly earlier
- reduce recovery DU envelope probability when already close to target
- reduce jackpot softness when overlay RTP exceeds target

### 12.4 Forbidden implementation examples

```csharp
// FORBIDDEN
if (bufferTriggered) payout = 0;

// FORBIDDEN
if (bufferTriggered) replace challengerCard;
```

---

## 13. Jackpot and Double-Up Guardrails

### 13.1 Leak definition

A leak is any overlay subsystem that continues contributing RTP above its allocated budget without feeding compensating pressure back into future control.

### 13.2 Jackpot guardrail

```csharp
private static decimal ApplyJackpotLeakGuard(decimal rawScale, MachinePolicyState state, EngineConfig cfg)
{
    if (state.JackpotRtp <= cfg.JackpotRtpSoftCap)
        return rawScale;

    var overflow = state.JackpotRtp - cfg.JackpotRtpSoftCap;
    var damp = overflow * cfg.JackpotLeakDamp;
    return rawScale - damp;
}
```

Rules:

- affects only future scale orbit and future deck-envelope softness
- never cancels a jackpot already won
- if hard cap is breached, switch to stricter pressure envelope until overlay returns to band

### 13.3 Double-up guardrail

```csharp
private static IReadOnlyList<CleanRoomCard> ApplyDoubleUpEnvelope(
    IReadOnlyList<CleanRoomCard> standardDeck,
    MachinePolicyState state,
    PolicyEnvelopeMode mode,
    ulong seed,
    EngineConfig cfg)
{
    if (state.DoubleUpRtp <= cfg.DoubleUpRtpSoftCap)
        return standardDeck;

    return mode switch
    {
        PolicyEnvelopeMode.Recovery => AddRecoveryDuPressure(standardDeck, seed, cfg),
        PolicyEnvelopeMode.Pressure => AddPressureDuEnvelope(standardDeck, seed, cfg),
        _ => standardDeck
    };
}
```

Rules:

- allowed levers are pre-shuffle only
- maximum envelope strength is +/- 1 card type addition/removal in one round
- no stacked heavy manipulation
- no post-choice overrides

### 13.4 Approved DU envelopes

#### RecoveryDU
- add 1 Ace OR add 1 `5S`
- only when cold/recovery and not already above DU soft cap

#### NeutralDU
- standard deck

#### PressureDU
- remove 1 Ace OR add 1 neutral bad card profile
- never both in the same resolution pass
- disabled during crisis recovery

### 13.5 Hard-stop safety behavior

If `DoubleUpRtp > DoubleUpRtpHardCap` for sustained windows:

- force `Pressure` envelope eligibility for DU shaping
- reduce base scale generosity on the next N policy windows
- do not remove visible double-up availability in v1 of the 80% pass

---

## 14. DeadZone and ConvergenceHorizon Integrity

### 14.1 DeadZone behavior

```text
if abs(Drift) <= DeadZone:
    CorrectionGainAdjustment = 0
```

Recommended:

- `DeadZone = 0.0125m` (1.25%)

Why:

- prevents small oscillation around target
- avoids visible mode thrash
- reduces low-sample overreaction compared with the 85% pass

### 14.2 ConvergenceHorizon behavior

```text
RampFactor = clamp(SessionRounds / ConvergenceHorizon, 0.0, 1.0)
```

Recommended:

- `ConvergenceHorizon = 320`

Why:

- slower and smoother than the 85% fast-pull regime
- keeps early rounds from snapping into pressure too quickly
- gives warmup decay enough room to transition cleanly

### 14.3 Anti-oscillation stack

The controller should rely on all of the following together:

1. drift smoothing window
2. dead zone
3. bounded correction
4. rolling-mean clamp
5. overlay leak damp
6. slow convergence ramp

Any implementation missing one of these should be considered incomplete.

---

## 15. Validation Harness - 500,000 Round Deterministic Certification

### 15.1 Goal

Upgrade `Lucky5.Simulation/Program.cs` from a balancing sandbox into an acceptance gate for the 80% design.

### 15.2 Required properties

- deterministic
- SplitMix64-based
- mirrors live service rules
- same deal + draw cost model
- same jackpot replacement behavior
- same unconditional double-up offer behavior unless changed explicitly in code
- same machine-close handling
- same take-half / cashout flows

### 15.3 Required simulation architecture

#### Option A - recommended
Build a service-parity harness that runs the same core policy and engine calls as live code, with a thin behavior driver.

```csharp
for (var roundIndex = 0; roundIndex < 500_000; roundIndex++)
{
    var seed = DeterministicSeed.FromString($"rtp80-{behavior}-{roundIndex}");
    var policyState = BuildPolicyState(ledger, session);
    var policy = MachinePolicy.ResolvePolicy(policyState, cfg, seed);

    var alteredDeck = MachinePolicy.AlterDeck(standardDeck, policy.EnvelopeMode, seed, ledger.ConsecutiveLosses);
    var shuffledDeck = FiveCardDrawEngine.ShuffleDeck(seed, "hand", alteredDeck);
    var drawState = RunHand(shuffledDeck, behavior);

    var payout = ResolveScaledPayout(drawState, policy);
    payout = ResolveJackpotOverlayIfAny(payout, ledger, cfg);
    payout = ResolveDoubleUpIfEntered(payout, behavior, ledger, session, policy, seed);

    RecordMetrics(roundIndex, policy, payout, ledger, session);
    UpdateRollingPolicyTelemetry(policy, ledger, session);
}
```

#### Option B - not sufficient alone
Pure approximation harnesses that ignore current live DU behavior or session semantics.

### 15.4 New metric model

```csharp
sealed class RecalibrationSimulationMetrics
{
    public decimal TotalIn { get; set; }
    public decimal BaseOut { get; set; }
    public decimal JackpotOut { get; set; }
    public decimal DoubleUpOut { get; set; }

    public int WarmupActivations { get; set; }
    public int PityActivations { get; set; }
    public int CrisisActivations { get; set; }

    public decimal WarmupCreditsDelta { get; set; }
    public decimal PityCreditsDelta { get; set; }
    public decimal CrisisCreditsDelta { get; set; }

    public List<decimal> WindowRtp1000 { get; } = new();
    public List<decimal> WindowRtp5000 { get; } = new();
    public List<decimal> WindowRtp50000 { get; } = new();

    public List<decimal> ScaleSamples { get; } = new();
    public List<decimal> JackpotRtpSamples { get; } = new();
    public List<decimal> DoubleUpRtpSamples { get; } = new();
    public Dictionary<PolicyEnvelopeMode, int> EnvelopeCounts { get; } = new();
}
```

### 15.5 Required pass / fail thresholds

#### Total convergence
- 500,000 rounds total RTP must finish in `79.50% - 80.50%`

#### Window convergence
- 1,000-round windows: mostly `74% - 86%`
- 5,000-round windows: mostly `77.5% - 82.5%`
- 50,000-round windows: all `79.0% - 81.0%`

#### Volatility
- 1,000-round window standard deviation `< 6.5%`
- 5,000-round window standard deviation `< 2.5%`
- no repeating sawtooth oscillation pattern for more than 3 consecutive windows

#### Base / overlay budget
- Base RTP: `67.25% - 68.25%`
- Jackpot RTP: `2.25% - 3.25%`
- Double-up RTP: `8.75% - 10.25%`

#### Warmup auditability
- warmup must lift early RTP, but its incremental contribution must decay toward zero by round ~3,000
- average warmup contribution per 100k rounds must be bounded and non-explosive

#### Pity auditability
- pity activation frequency must be measurable and stable
- pity net delta must remain long-run bounded
- pity + crisis combined contribution must not exceed `+0.75 RTP points` over 500k rounds

#### Leak safety
- Jackpot soft-cap breach windows must self-correct within 10k rounds
- Double-up soft-cap breach windows must self-correct within 15k rounds

### 15.6 Output report requirements

The harness must print:

1. total RTP summary
2. component RTP summary
3. window-volatility table
4. envelope distribution table
5. warmup and pity contribution table
6. top 10 worst and best 5k windows
7. leak-breach counts and time-to-recovery

---

## 16. Regression Test Additions

### 16.1 CleanRoom tests

Add assertions for:

- dead zone yields zero correction inside threshold
- correction caps at `MaxCorrection`
- warmup bias decays to zero by `WarmupRounds`
- pity boost caps at `PityBoostCap`
- envelope clamp respects rolling mean bounds
- house-edge buffer never exceeds `HouseEdgeBufferCap`

### 16.2 DTO tests

Add assertions for:

- `MachineSessionDto.Transparency` is null-safe
- `MachineTransparencyDto` serializes predictably
- envelope enum maps to approved strings only

### 16.3 Simulation gate tests

Add a smoke certification mode:

- 10k quick gate on CI
- 100k medium gate locally / pre-merge
- 500k certification gate on release candidates

---

## 17. File-by-File Engineering Tasks

### 17.1 `CoreModels.cs`

Implement:

- new 80% targets
- new smoothing / buffer / guardrail parameters
- helper properties for target base RTP and bounded house-edge buffer

### 17.2 `MachinePolicy.cs`

Implement:

- `ResolvePolicy(...)`
- `ResolveCorrectionGainAdjustment(...)`
- `ResolvePityBoost(...)`
- `ResolveEnvelopeMode(...)`
- `ApplyOverlayLeakDamp(...)`
- `ApplyWarmupBias(...)`
- `UpdateRollingMeanScale(...)`
- DU envelope helpers

### 17.3 `GameService.cs`

Implement:

- persist latest transparency snapshot per machine session
- map policy transparency to DTOs
- keep service logic free of actual math beyond calling policy functions

### 17.4 `MachineSessionDto.cs` + new transparency DTO

Implement additive session payload support.

### 17.5 `Lucky5.Simulation/Program.cs`

Implement:

- 500k certification mode
- component metrics
- envelope tracking
- warmup / pity contribution tracking
- leak recovery tracking

### 17.6 tests

Implement:

- unit tests for math
- regression tests for envelope guardrails
- certification smoke gate

---

## 18. Rollout Plan

### Step 1
Land DTO + policy scaffolding behind config defaults.

### Step 2
Land 80% config and new controller formulas.

### Step 3
Update simulation for full parity and run 100k / 500k.

### Step 4
Only after simulation passes, update authoritative docs and any onboarding references.

---

## 19. Definition of Done

The 80% recalibration update is ready only when all of the following are true:

1. `EngineConfig` expresses the 80% allocation explicitly
2. `MachinePolicy` computes scale from `BaseScale + CorrectionGainAdjustment + WarmupBias + PityBoost`
3. `HouseEdgeBuffer` is bounded and never used as an outcome override
4. `MachineSessionDto` exposes transparency state safely
5. jackpot and double-up leak guards feed back into future control only
6. 500,000-round deterministic simulation passes the defined thresholds
7. no visible rule changes were introduced accidentally

---

## 20. Recommended Next Command Sequence

```bash
dotnet build server/Lucky5.sln -v minimal
dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj
dotnet run --project server/src/Lucky5.Simulation/Lucky5.Simulation.csproj -- --mode quick-10k
dotnet run --project server/src/Lucky5.Simulation/Lucky5.Simulation.csproj -- --mode medium-100k
dotnet run --project server/src/Lucky5.Simulation/Lucky5.Simulation.csproj -- --mode certify-500k
```

