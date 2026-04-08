namespace Lucky5.Application.Dtos;

/// <summary>
/// Player-visible and operator-auditable telemetry for RTP pacing disclosures.
/// This mirrors deterministic policy state and must never imply post-choice rigging.
/// </summary>
public sealed record MachineTransparencyDto(
    bool IsWarmupActive,
    bool IsPityActive,
    bool IsCrisisActive,
    decimal EffectiveScale,
    decimal BaseScale,
    decimal WarmupBias,
    decimal PityBoost,
    decimal JackpotLeakAdjustment,
    decimal DoubleUpLeakAdjustment,
    string EnvelopeMode,
    int RoundCount,
    int ConsecutiveLosses,
    int RoundsSinceMediumWin,
    decimal ObservedRtp,
    decimal TargetRtp);
