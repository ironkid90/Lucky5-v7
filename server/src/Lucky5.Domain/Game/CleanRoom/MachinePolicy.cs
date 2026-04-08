namespace Lucky5.Domain.Game.CleanRoom;

public enum PolicyDistributionMode
{
    Cold = 0,
    Neutral = 1,
    Hot = 2
}

public enum PayoutTier
{
    Small = 0,
    Medium = 1,
    Big = 2
}

public sealed class MachinePolicyState
{
    public decimal CreditsIn { get; set; }
    public decimal CreditsOut { get; set; }
    public decimal BaseCreditsOut { get; set; }
    public decimal JackpotCreditsOut { get; set; }
    public decimal DoubleUpCreditsOut { get; set; }
    public decimal TargetRtp { get; set; } = 0.85m;
    public int RoundCount { get; set; }

    public int ConsecutiveLosses { get; set; }
    public int RoundsSinceMediumWin { get; set; }
    public int CooldownRoundsRemaining { get; set; }

    public decimal NetSinceLastClose { get; set; }
    public int RoundsSinceLucky5Hit { get; set; }

    public decimal ObservedRtp => CreditsIn <= 0m ? TargetRtp : decimal.Round(CreditsOut / CreditsIn, 4);
    public decimal BaseRtp => CreditsIn <= 0m ? 0.3200m : decimal.Round(BaseCreditsOut / CreditsIn, 4);
    public decimal JackpotRtp => CreditsIn <= 0m ? 0m : decimal.Round(JackpotCreditsOut / CreditsIn, 4);
    public decimal DoubleUpRtp => CreditsIn <= 0m ? 0m : decimal.Round(DoubleUpCreditsOut / CreditsIn, 4);
    public decimal Drift => ObservedRtp - TargetRtp;

    public decimal ComputeSmoothedObservedRtp(EngineConfig? config = null)
    {
        var cfg = config ?? EngineConfig.Default;
        var window = Math.Max(1, cfg.RtpSmoothingWindow);
        var rounds = Math.Max(0, RoundCount);

        if (rounds <= 0 || CreditsIn <= 0m)
        {
            return TargetRtp;
        }

        var sampleWeight = Math.Min(1m, rounds / (decimal)Math.Max(cfg.RtpMinSamplesForControl, 1));
        var windowWeight = Math.Min(1m, CreditsIn / window);
        var blend = Math.Min(1m, Math.Max(sampleWeight, windowWeight));

        return decimal.Round((ObservedRtp * blend) + (TargetRtp * (1m - blend)), 4);
    }

    public decimal ComputeSmoothedDrift(EngineConfig? config = null)
    {
        var cfg = config ?? EngineConfig.Default;
        var smoothedObserved = ComputeSmoothedObservedRtp(cfg);
        var raw = smoothedObserved - TargetRtp;
        return Math.Clamp(raw, -cfg.MaxDriftClamp, cfg.MaxDriftClamp);
    }
}

public readonly record struct PayoutScaleResult(
    decimal SmallScale,
    decimal MediumScale,
    decimal BigScale)
{
    public decimal ForTier(PayoutTier tier) => tier switch
    {
        PayoutTier.Small => SmallScale,
        PayoutTier.Medium => MediumScale,
        PayoutTier.Big => BigScale,
        _ => SmallScale
    };
}

public static class MachinePolicy
{
    private static readonly CleanRoomCard FiveOfSpades = new(5, 'S');
    private static readonly int[] HighValueRanks = [14, 13, 12, 11];

    // All tuning constants now come from EngineConfig; these are convenience accessors for the default.
    private static EngineConfig Cfg => EngineConfig.Default;

    public static decimal CloseThreshold => Cfg.CloseThreshold;

    public static PayoutTier ClassifyHand(HandCategory category) => category switch
    {
        HandCategory.TwoPair => PayoutTier.Small,
        HandCategory.ThreeOfAKind => PayoutTier.Small,
        HandCategory.Straight => PayoutTier.Medium,
        HandCategory.Flush => PayoutTier.Medium,
        HandCategory.FullHouse => PayoutTier.Medium,
        HandCategory.FourOfAKind => PayoutTier.Big,
        HandCategory.StraightFlush => PayoutTier.Big,
        HandCategory.RoyalFlush => PayoutTier.Big,
        _ => PayoutTier.Small
    };

    public static bool IsSoftCapActive(decimal netSinceLastClose) => netSinceLastClose >= Cfg.SoftCapHard;
    public static bool IsSoftCapWarning(decimal netSinceLastClose) => netSinceLastClose >= Cfg.SoftCapWarning;

    // ---------- Distribution Mode ----------

    public static PolicyDistributionMode ResolveDistributionMode(
        MachinePolicyState state,
        ulong entropySeed,
        EngineConfig? config = null)
    {
        var cfg = config ?? Cfg;

        if (state.NetSinceLastClose >= cfg.CloseThreshold)
            return PolicyDistributionMode.Hot;

        if (state.NetSinceLastClose >= cfg.SoftCapHard)
            return PolicyDistributionMode.Hot;

        if (state.ConsecutiveLosses >= cfg.StreakHardThreshold + 5)
            return PolicyDistributionMode.Hot;

        if (state.CooldownRoundsRemaining > 0
            && state.ConsecutiveLosses < cfg.StreakSoftThreshold
            && state.NetSinceLastClose < cfg.CloseThreshold)
            return PolicyDistributionMode.Neutral;

        var drift = state.ComputeSmoothedDrift(cfg);
        var rng = new SplitMix64Rng(DeterministicSeed.Derive(entropySeed, "policy-mode"));
        var noise = (decimal)((rng.NextUnit() - 0.5) * (double)(cfg.JitterAmplitude * 2m));
        var adjustedDrift = drift + noise;

        var streakBoost = ComputeStreakBoost(state, cfg);
        adjustedDrift -= streakBoost;

        if (state.RoundsSinceLucky5Hit >= 40)
            adjustedDrift -= 0.05m;
        else if (state.RoundsSinceLucky5Hit >= 20)
            adjustedDrift -= 0.02m;

        if (state.NetSinceLastClose >= cfg.SoftCapWarning)
        {
            var capPressure = (state.NetSinceLastClose - cfg.SoftCapWarning) / (cfg.SoftCapHard - cfg.SoftCapWarning);
            adjustedDrift -= capPressure * 0.08m;
        }

        if (adjustedDrift > cfg.DeadZone)
            return PolicyDistributionMode.Cold;

        if (adjustedDrift < -cfg.DeadZone)
            return PolicyDistributionMode.Hot;

        return PolicyDistributionMode.Neutral;
    }

    // ---------- Payout Scale (symmetric controller, no fun-pressure) ----------

    public static PayoutScaleResult ResolvePayoutScale(
        MachinePolicyState state,
        ulong entropySeed,
        EngineConfig? config = null)
    {
        var cfg = config ?? Cfg;
        var rng = new SplitMix64Rng(DeterministicSeed.Derive(entropySeed, "payout-scale"));
        var jitter = (decimal)((rng.NextUnit() - 0.5) * (double)cfg.JitterAmplitude);

        var liveScale = ResolveLivePayoutScale(state, jitter, cfg);

        if (state.RoundCount < cfg.WarmupRounds)
        {
            var warmupProgress = cfg.WarmupRounds <= 1
                ? 1m
                : Math.Clamp((state.RoundCount - 1m) / (cfg.WarmupRounds - 1m), 0m, 1m);

            return new PayoutScaleResult(
                Lerp(cfg.WarmupOpeningSmallScale, liveScale.SmallScale, warmupProgress),
                Lerp(cfg.WarmupOpeningMediumScale, liveScale.MediumScale, warmupProgress),
                Lerp(cfg.WarmupOpeningBigScale, liveScale.BigScale, warmupProgress));
        }

        return liveScale;
    }

    private static PayoutScaleResult ResolveLivePayoutScale(MachinePolicyState state, decimal jitter, EngineConfig cfg)
    {
        var observedBaseRtp = Math.Max(state.BaseRtp, cfg.MinimumObservedBaseRtp);
        var targetRtp = state.TargetRtp == 0m ? cfg.TargetRtp : state.TargetRtp;
        var targetBaseRtp = Math.Max(0.10m, targetRtp - cfg.TargetDoubleUpRtp - state.JackpotRtp);
        var equilibriumScale = targetBaseRtp / observedBaseRtp;
        var rampFactor = cfg.ConvergenceHorizon <= 0
            ? 1m
            : Math.Min(1m, state.RoundCount / (decimal)cfg.ConvergenceHorizon);
        var drift = state.ComputeSmoothedDrift(cfg);

        decimal correction;
        if (Math.Abs(drift) <= cfg.DeadZone)
        {
            correction = 0m;
        }
        else
        {
            correction = Math.Clamp(-drift * cfg.CorrectionGain * rampFactor, -cfg.MaxCorrection, cfg.MaxCorrection);
        }

        decimal crisisBoost = 0m;
        if (state.ConsecutiveLosses >= cfg.CrisisThreshold)
            crisisBoost = cfg.CrisisScaleBoost;

        var warmupBias = 0m;
        if (state.RoundCount > 0 && state.RoundCount <= cfg.WarmupRounds)
        {
            var decay = cfg.WarmupRounds <= 1
                ? 0m
                : 1m - ((state.RoundCount - 1m) / (cfg.WarmupRounds - 1m));
            warmupBias = Math.Max(0m, decay) * 0.08m;
        }

        var rawScale = equilibriumScale + correction + warmupBias + jitter + crisisBoost;
        var smallScale = rawScale * cfg.SmallTierFactor;
        var mediumScale = rawScale * cfg.MediumTierFactor;
        var bigScale = rawScale * cfg.BigTierFactor;

        return new PayoutScaleResult(
            Math.Clamp(smallScale, cfg.MinPayoutScale, cfg.MaxPayoutScale),
            Math.Clamp(mediumScale, cfg.MinPayoutScale, cfg.MaxPayoutScale),
            Math.Clamp(bigScale, cfg.MinPayoutScale, cfg.MaxPayoutScale));
    }

    public static decimal ResolvePayoutScaleFlat(MachinePolicyState state, ulong entropySeed, EngineConfig? config = null)
    {
        var tiered = ResolvePayoutScale(state, entropySeed, config);
        return tiered.SmallScale;
    }

    // ---------- Unified Policy Entry Point ----------

    /// <summary>
    /// Unified policy resolution that returns telemetry alongside the effective scale.
    /// This replaces the piecemeal ResolvePayoutScale calls over time.
    /// </summary>
    public static MachinePolicyResolution ResolvePolicy(MachinePolicyState state, ulong entropySeed, EngineConfig? config = null)
    {
        var cfg = config ?? Cfg;
        var distributionMode = ResolveDistributionMode(state, entropySeed, cfg);
        var payoutScale = ResolvePayoutScale(state, entropySeed, cfg);
        
        // Compute individual adjustment components for telemetry
        var baseScale = ComputeBaseScale(state, cfg);
        var correctionGainAdjustment = ComputeCorrectionGainAdjustment(state, cfg);
        var warmupBias = ComputeWarmupBias(state, cfg);
        var pityBoost = ComputePityBoost(state, cfg);
        var jackpotLeakAdjustment = ComputeJackpotLeakAdjustment(state, cfg);
        var doubleUpLeakAdjustment = ComputeDoubleUpLeakAdjustment(state, cfg);
        
        var effectiveScale = payoutScale.SmallScale; // Base effective scale
        var envelopeMode = ResolveEnvelopeMode(state, distributionMode, cfg);
        
        var isWarmupActive = state.RoundCount < cfg.WarmupRounds;
        var isPityActive = pityBoost > 0m;
        var isCrisisActive = state.ConsecutiveLosses >= cfg.CrisisThreshold;
        
        var telemetry = new MachinePolicyTelemetry(
            IsWarmupActive: isWarmupActive,
            IsPityActive: isPityActive,
            IsCrisisActive: isCrisisActive,
            BaseScale: baseScale,
            WarmupBias: warmupBias,
            PityBoost: pityBoost,
            JackpotLeakAdjustment: jackpotLeakAdjustment,
            DoubleUpLeakAdjustment: doubleUpLeakAdjustment,
            EffectiveScale: effectiveScale,
            EnvelopeMode: envelopeMode,
            RoundCount: state.RoundCount,
            ConsecutiveLosses: state.ConsecutiveLosses,
            RoundsSinceMediumWin: state.RoundsSinceMediumWin,
            ObservedRtp: state.ObservedRtp,
            TargetRtp: state.TargetRtp);
        
        return new MachinePolicyResolution(
            EffectiveScale: effectiveScale,
            DistributionMode: distributionMode,
            EnvelopeMode: envelopeMode,
            Telemetry: telemetry);
    }

    private static decimal ComputeBaseScale(MachinePolicyState state, EngineConfig cfg)
    {
        var observedBaseRtp = Math.Max(state.BaseRtp, cfg.MinimumObservedBaseRtp);
        var targetRtp = state.TargetRtp == 0m ? cfg.TargetRtp : state.TargetRtp;
        var targetBaseRtp = Math.Max(0.10m, targetRtp - cfg.TargetDoubleUpRtp - state.JackpotRtp);
        return targetBaseRtp / observedBaseRtp;
    }

    private static decimal ComputeCorrectionGainAdjustment(MachinePolicyState state, EngineConfig cfg)
    {
        var drift = state.ComputeSmoothedDrift(cfg);
        var rampFactor = cfg.ConvergenceHorizon <= 0
            ? 1m
            : Math.Min(1m, state.RoundCount / (decimal)cfg.ConvergenceHorizon);
        
        if (Math.Abs(drift) <= cfg.DeadZone)
            return 0m;
        
        return Math.Clamp(-drift * cfg.CorrectionGain * rampFactor, -cfg.MaxCorrection, cfg.MaxCorrection);
    }

    private static decimal ComputeWarmupBias(MachinePolicyState state, EngineConfig cfg)
    {
        if (state.RoundCount <= 0 || state.RoundCount > cfg.WarmupRounds)
            return 0m;
        
        var decay = cfg.WarmupRounds <= 1
            ? 0m
            : 1m - ((state.RoundCount - 1m) / (cfg.WarmupRounds - 1m));
        return Math.Max(0m, decay) * 0.08m;
    }

    private static decimal ComputePityBoost(MachinePolicyState state, EngineConfig cfg)
    {
        decimal boost = 0m;
        
        if (state.ConsecutiveLosses >= cfg.StreakHardThreshold)
            boost += 0.06m;
        else if (state.ConsecutiveLosses >= cfg.StreakSoftThreshold)
        {
            var progress = (decimal)(state.ConsecutiveLosses - cfg.StreakSoftThreshold) / (cfg.StreakHardThreshold - cfg.StreakSoftThreshold);
            boost += 0.02m + progress * 0.04m;
        }
        
        if (state.RoundsSinceMediumWin >= cfg.MediumWinDroughtThreshold)
            boost += 0.02m;
        
        return boost;
    }

    private static decimal ComputeJackpotLeakAdjustment(MachinePolicyState state, EngineConfig cfg)
    {
        // Apply jackpot RTP cap as a negative adjustment
        if (state.JackpotRtp > cfg.JackpotRtpSoftCap)
        {
            var excess = state.JackpotRtp - cfg.JackpotRtpSoftCap;
            return -excess * cfg.JackpotLeakDamp;
        }
        return 0m;
    }

    private static decimal ComputeDoubleUpLeakAdjustment(MachinePolicyState state, EngineConfig cfg)
    {
        // Apply double-up RTP cap as a negative adjustment
        if (state.DoubleUpRtp > cfg.DoubleUpRtpHardCap)
        {
            var excess = state.DoubleUpRtp - cfg.DoubleUpRtpHardCap;
            return -excess * 0.5m; // Simple damping factor
        }
        return 0m;
    }

    private static PolicyEnvelopeMode ResolveEnvelopeMode(MachinePolicyState state, PolicyDistributionMode distributionMode, EngineConfig cfg)
    {
        if (state.RoundCount < cfg.WarmupRounds)
            return PolicyEnvelopeMode.Recovery;
        
        if (state.CooldownRoundsRemaining > 0)
            return PolicyEnvelopeMode.Cooldown;
        
        if (state.NetSinceLastClose >= cfg.SoftCapHard)
            return PolicyEnvelopeMode.Pressure;
        
        return distributionMode switch
        {
            PolicyDistributionMode.Cold => PolicyEnvelopeMode.Pressure,
            PolicyDistributionMode.Hot => PolicyEnvelopeMode.Recovery,
            _ => PolicyEnvelopeMode.Neutral
        };
    }

    // ---------- Double-Up Offer Curve ----------

    public static decimal ComputeDoubleUpOfferRate(MachinePolicyState state, EngineConfig? config = null)
    {
        var cfg = config ?? Cfg;
        var drift = state.Drift;

        if (drift >= cfg.DoubleUpHighDriftThreshold)
        {
            return cfg.DoubleUpOfferFloor;
        }

        if (drift >= cfg.DoubleUpTargetUpperThreshold)
        {
            var overTargetT = (drift - cfg.DoubleUpTargetUpperThreshold)
                / (cfg.DoubleUpHighDriftThreshold - cfg.DoubleUpTargetUpperThreshold);

            return Lerp(cfg.DoubleUpOfferOverTargetBand, cfg.DoubleUpOfferFloor, Math.Clamp(overTargetT, 0m, 1m));
        }

        if (drift >= cfg.DoubleUpTargetLowerThreshold)
        {
            return cfg.DoubleUpOfferTargetBand;
        }

        if (drift >= cfg.DoubleUpRecoveryThreshold)
        {
            var recoveryT = (cfg.DoubleUpTargetLowerThreshold - drift)
                / (cfg.DoubleUpTargetLowerThreshold - cfg.DoubleUpRecoveryThreshold);

            return Lerp(cfg.DoubleUpOfferTargetBand, cfg.DoubleUpOfferRecoveryBand, Math.Clamp(recoveryT, 0m, 1m));
        }

        return cfg.DoubleUpOfferMax;
    }

    /// <summary>
    /// Returns true if double-up should be offered to the player this round.
    /// </summary>
    public static bool ShouldOfferDoubleUp(MachinePolicyState state, ulong entropySeed, EngineConfig? config = null)
    {
        // Double-up is always available to players without exception. 
        // We manipulate the deck instead of the offer availability.
        return true;
    }

    // ---------- Cooldown ----------

    public static int ComputeCooldownLength(HandCategory winCategory, ulong entropySeed, EngineConfig? config = null)
    {
        var cfg = config ?? Cfg;
        var rng = new SplitMix64Rng(DeterministicSeed.Derive(entropySeed, "cooldown-jitter"));
        var jitter = rng.NextInt(3) - 1;

        var baseCooldown = winCategory switch
        {
            HandCategory.FourOfAKind or HandCategory.StraightFlush or HandCategory.RoyalFlush => cfg.CooldownLength + 1,
            HandCategory.FullHouse or HandCategory.Flush or HandCategory.Straight => cfg.CooldownLength,
            _ => Math.Max(cfg.CooldownLength - 1, 1)
        };

        return Math.Max(baseCooldown + jitter, 1);
    }

    // Overload for simulation compatibility (no entropy seed)
    public static int ComputeCooldownLength(HandCategory winCategory, EngineConfig? config = null)
    {
        var cfg = config ?? Cfg;
        return winCategory switch
        {
            HandCategory.FourOfAKind or HandCategory.StraightFlush or HandCategory.RoyalFlush => cfg.CooldownLength + 1,
            HandCategory.FullHouse or HandCategory.Flush or HandCategory.Straight => cfg.CooldownLength,
            _ => Math.Max(cfg.CooldownLength - 1, 1)
        };
    }

    // ---------- Double-Up Deck (no alteration — standard deck only) ----------

    public static CleanRoomCard[] BuildDoubleUpDeck(
        CleanRoomCard[] standardDeck,
        ulong entropySeed,
        int roundsSinceLucky5Hit,
        decimal netSinceLastClose,
        PolicyDistributionMode roundPolicyMode)
    {
        // Per architecture: remove all DU deck alteration. Return standard deck only.
        return standardDeck;
    }

    // ---------- Streak Boost ----------

    private static decimal ComputeStreakBoost(MachinePolicyState state, EngineConfig? config = null)
    {
        var cfg = config ?? Cfg;
        decimal boost = 0m;

        if (state.ConsecutiveLosses >= cfg.StreakHardThreshold)
        {
            boost += 0.06m;
        }
        else if (state.ConsecutiveLosses >= cfg.StreakSoftThreshold)
        {
            var progress = (decimal)(state.ConsecutiveLosses - cfg.StreakSoftThreshold) / (cfg.StreakHardThreshold - cfg.StreakSoftThreshold);
            boost += 0.02m + progress * 0.04m;
        }

        if (state.RoundsSinceMediumWin >= cfg.MediumWinDroughtThreshold)
        {
            boost += 0.02m;
        }

        return boost;
    }

    private static decimal Lerp(decimal start, decimal end, decimal amount)
        => start + ((end - start) * Math.Clamp(amount, 0m, 1m));

    // ---------- Deck Alteration (bounded: ±2 cards) ----------

    public static CleanRoomCard[] AlterDeck(
        CleanRoomCard[] standardDeck,
        PolicyDistributionMode mode,
        ulong entropySeed,
        int consecutiveLosses = 0,
        EngineConfig? config = null)
    {
        if (mode == PolicyDistributionMode.Neutral)
            return standardDeck;

        var cfg = config ?? Cfg;
        var rng = new SplitMix64Rng(DeterministicSeed.Derive(entropySeed, "policy-alter"));

        if (mode == PolicyDistributionMode.Cold)
            return AlterDeckCold(standardDeck, rng, cfg);

        return AlterDeckHot(standardDeck, rng, consecutiveLosses, cfg);
    }

    private static CleanRoomCard[] AlterDeckCold(CleanRoomCard[] deck, SplitMix64Rng rng, EngineConfig? config = null)
    {
        var cfg = config ?? Cfg;
        var altered = new List<CleanRoomCard>(deck.Length);
        var removals = 0;

        foreach (var card in deck)
        {
            if (removals >= cfg.MaxColdRemovals)
            {
                altered.Add(card);
                continue;
            }

            // Never remove 5♠
            if (cfg.NeverRemoveFiveOfSpades && card.Rank == FiveOfSpades.Rank && card.Suit == FiveOfSpades.Suit)
            {
                altered.Add(card);
                continue;
            }

            if (Array.IndexOf(HighValueRanks, card.Rank) >= 0 && rng.NextUnit() < 0.30)
            {
                removals++;
                continue;
            }

            altered.Add(card);
        }

        if (altered.Count < cfg.MinDeckSize)
            return deck;

        return altered.ToArray();
    }

    private static CleanRoomCard[] AlterDeckHot(CleanRoomCard[] deck, SplitMix64Rng rng, int consecutiveLosses, EngineConfig? config = null)
    {
        var cfg = config ?? Cfg;
        var altered = new List<CleanRoomCard>(deck);
        var additions = 0;

        // First addition: 5♠ (pity-timer gated)
        if (consecutiveLosses >= cfg.StreakSoftThreshold && rng.NextUnit() < 0.40 && additions < cfg.MaxHotAdditions)
        {
            altered.Add(FiveOfSpades);
            additions++;
        }

        // Second addition: one high card
        if (consecutiveLosses >= cfg.StreakHardThreshold && rng.NextUnit() < 0.25 && additions < cfg.MaxHotAdditions)
        {
            var rank = HighValueRanks[rng.NextInt(HighValueRanks.Length)];
            char suit = "SHDC"[rng.NextInt(4)];
            altered.Add(new CleanRoomCard(rank, suit));
            additions++;
        }

        return altered.ToArray();
    }
}
