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
    public decimal TargetRtp { get; set; } = 0.875m;
    public int RoundCount { get; set; }

    public int ConsecutiveLosses { get; set; }
    public int RoundsSinceMediumWin { get; set; }
    public int CooldownRoundsRemaining { get; set; }

    public decimal NetSinceLastClose { get; set; }
    public int RoundsSinceLucky5Hit { get; set; }

    public decimal ObservedRtp => CreditsIn <= 0m ? TargetRtp : decimal.Round(CreditsOut / CreditsIn, 4);
    public decimal BaseRtp => CreditsIn <= 0m ? 0.38m : decimal.Round(BaseCreditsOut / CreditsIn, 4);
    public decimal JackpotRtp => CreditsIn <= 0m ? 0m : decimal.Round(Math.Max(CreditsOut - BaseCreditsOut, 0m) / CreditsIn, 4);
    public decimal Drift => ObservedRtp - TargetRtp;
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

    public const decimal CloseThreshold = 50_000_000m;

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

        var drift = state.Drift;
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

        if (state.RoundCount < cfg.WarmupRounds)
        {
            return new PayoutScaleResult(cfg.DefaultPayoutScale, cfg.DefaultPayoutScale * 1.15m, cfg.DefaultPayoutScale * 1.25m);
        }

        var baseRtp = state.BaseRtp;
        if (baseRtp <= 0m)
        {
            return new PayoutScaleResult(cfg.MaxPayoutScale, cfg.MaxPayoutScale, cfg.MaxPayoutScale);
        }

        var jackpotRtp = state.JackpotRtp;
        var targetBaseRtp = Math.Max(0.10m, state.TargetRtp - jackpotRtp);
        var requiredScale = targetBaseRtp / baseRtp;
        var drift = state.Drift;

        // Symmetric correction — same gain in both directions, clamped to ±MaxCorrection.
        // Dead zone: no correction when |drift| <= DeadZone (prevents hunting).
        decimal correction;
        if (Math.Abs(drift) <= cfg.DeadZone)
        {
            correction = 0m;
        }
        else
        {
            correction = Math.Clamp(-drift * cfg.CorrectionGain, -cfg.MaxCorrection, cfg.MaxCorrection);
        }

        // Crisis scale boost for extreme loss streaks
        decimal crisisBoost = 0m;
        if (state.ConsecutiveLosses >= cfg.CrisisThreshold)
            crisisBoost = cfg.CrisisScaleBoost;

        var rng = new SplitMix64Rng(DeterministicSeed.Derive(entropySeed, "payout-scale"));
        var jitter = (decimal)((rng.NextUnit() - 0.5) * (double)cfg.JitterAmplitude);

        var baseScale = requiredScale + correction + jitter + crisisBoost;

        // Hot-state win chunking: suppress BigScale when cooling down
        var bigMultiplier = state.CooldownRoundsRemaining > 0 ? 1.02m : 1.08m;

        var smallScale = baseScale * 0.96m;
        var mediumScale = baseScale * 1.02m;
        var bigScale = baseScale * bigMultiplier;

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

    // ---------- Double-Up Quantum Offer Gate ----------

    /// <summary>
    /// Computes the probability that the player is offered double-up on this round.
    /// When RTP is above target, the offer is suppressed. When below, it opens up.
    /// This is the primary RTP control lever for the unlimited DU system.
    /// </summary>
    public static decimal ComputeDoubleUpOfferRate(MachinePolicyState state, EngineConfig? config = null)
    {
        var cfg = config ?? Cfg;
        var drift = state.Drift;

        if (drift > cfg.DeadZone)
        {
            // Over target — suppress DU offers strongly (RTP too high)
            return 0m;
        }

        if (Math.Abs(drift) <= cfg.DeadZone)
        {
            // At target — offer at baseline
            return cfg.DoubleUpOfferAtTarget;
        }

        // Under target — ramp up offers linearly toward OfferMax
        var underTarget = -drift - cfg.DeadZone;
        var rampRange = 0.10m; // full ramp over 10% undershoot
        var t = Math.Min(underTarget / rampRange, 1.0m);
        return cfg.DoubleUpOfferAtTarget + t * (cfg.DoubleUpOfferMax - cfg.DoubleUpOfferAtTarget);
    }

    /// <summary>
    /// Returns true if double-up should be offered to the player this round.
    /// </summary>
    public static bool ShouldOfferDoubleUp(MachinePolicyState state, ulong entropySeed, EngineConfig? config = null)
    {
        var rate = ComputeDoubleUpOfferRate(state, config);
        if (rate <= 0m) return false;
        if (rate >= 1m) return true;
        var rng = new SplitMix64Rng(DeterministicSeed.Derive(entropySeed, "du-offer"));
        return (decimal)rng.NextUnit() < rate;
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
