namespace Lucky5.Domain.Game.CleanRoom;

using System.Globalization;
using Lucky5.Domain.Entities;

public enum RoundState
{
    Bet = 0,
    Deal5 = 1,
    Hold = 2,
    Draw = 3,
    Evaluate = 4,
    DoubleUp = 5
}

public enum RoundPhase
{
    Dealt = 0,
    Drawn = 1
}

public enum RoundActionKind
{
    ToggleHold = 0,
    SetHoldMask = 1,
    Draw = 2
}

public enum BigSmallGuess
{
    Big = 0,
    Small = 1
}

public enum HandCategory
{
    HighCard = 0,
    OnePair = 1,
    TwoPair = 2,
    ThreeOfAKind = 3,
    Straight = 4,
    Flush = 5,
    FullHouse = 6,
    FourOfAKind = 7,
    StraightFlush = 8,
    RoyalFlush = 9
}

public enum Lucky5DoubleUpOutcome
{
    Win = 0,
    Lose = 1,
    SafeFail = 2,
    MachineClosed = 3
}

public sealed record RoundAction(RoundActionKind Kind, int? CardIndex = null, bool[]? HoldMask = null);

public readonly record struct CleanRoomCard(int Rank, char Suit)
{
    private const string ValidSuits = "CDHS";

    public string Code => $"{GetDisplayRank(Rank)}{Suit}";

    public static CleanRoomCard FromCode(string code)
    {
        if (string.IsNullOrWhiteSpace(code))
        {
            throw new ArgumentException("Card code is required.", nameof(code));
        }

        var normalized = code.Trim().ToUpperInvariant().Replace("10", "T", StringComparison.Ordinal);
        if (normalized.Length != 2)
        {
            throw new ArgumentException($"Invalid card code: {code}", nameof(code));
        }

        var suit = normalized[1];
        if (!ValidSuits.Contains(suit, StringComparison.Ordinal))
        {
            throw new ArgumentException($"Unsupported suit in card code: {code}", nameof(code));
        }

        return new CleanRoomCard(ParseRank(normalized[0]), suit);
    }

    public PokerCard ToLegacyPokerCard() => new(GetLegacyRank(Rank), Suit.ToString());

    public static int ParseRank(char rank) => rank switch
    {
        '2' => 2,
        '3' => 3,
        '4' => 4,
        '5' => 5,
        '6' => 6,
        '7' => 7,
        '8' => 8,
        '9' => 9,
        'T' => 10,
        'J' => 11,
        'Q' => 12,
        'K' => 13,
        'A' => 14,
        _ => throw new ArgumentOutOfRangeException(nameof(rank), rank, "Unsupported rank character.")
    };

    public static string GetDisplayRank(int rank) => rank switch
    {
        >= 2 and <= 9 => rank.ToString(CultureInfo.InvariantCulture),
        10 => "T",
        11 => "J",
        12 => "Q",
        13 => "K",
        14 => "A",
        _ => throw new ArgumentOutOfRangeException(nameof(rank), rank, "Unsupported rank value.")
    };

    public static string GetLegacyRank(int rank) => rank == 10 ? "10" : GetDisplayRank(rank);
}

public sealed record FiveCardDrawState(
    ulong SeedToken,
    CleanRoomCard[] Deck,
    CleanRoomCard[] Hand,
    int DrawIndex,
    bool[] Held,
    RoundPhase Phase,
    RoundState State)
{
    public static FiveCardDrawState Create(ulong seedToken, CleanRoomCard[] deck, CleanRoomCard[] hand)
        => new(seedToken, deck, hand, 5, [false, false, false, false, false], RoundPhase.Dealt, RoundState.Hold);
}

public sealed record HandEvaluation(
    HandCategory Category,
    string DisplayName,
    int[] Tiebreak,
    int? PairRank = null);

public sealed record PaytableProfile(
    string Name,
    IReadOnlyDictionary<HandCategory, int> Payouts,
    int MinimumPairRankForPayout = 11,
    int MaxCoinBet = 5,
    int RoyalFlushMaxCoinPayout = 4000)
{
    public static PaytableProfile Lebanese { get; } = new(
        "Lebanese",
        new Dictionary<HandCategory, int>
        {
            [HandCategory.RoyalFlush] = 1000,
            [HandCategory.StraightFlush] = 75,
            [HandCategory.FourOfAKind] = 15,
            [HandCategory.FullHouse] = 12,
            [HandCategory.Flush] = 10,
            [HandCategory.Straight] = 8,
            [HandCategory.ThreeOfAKind] = 3,
            [HandCategory.TwoPair] = 2
        },
        int.MaxValue,
        MaxCoinBet: 5,
        RoyalFlushMaxCoinPayout: 5_000_000);

    public static PaytableProfile JacksOrBetter { get; } = new(
        "Jacks or Better",
        new Dictionary<HandCategory, int>
        {
            [HandCategory.RoyalFlush] = 250,
            [HandCategory.StraightFlush] = 50,
            [HandCategory.FourOfAKind] = 25,
            [HandCategory.FullHouse] = 9,
            [HandCategory.Flush] = 6,
            [HandCategory.Straight] = 4,
            [HandCategory.ThreeOfAKind] = 3,
            [HandCategory.TwoPair] = 2,
            [HandCategory.OnePair] = 1
        });

    public static PaytableProfile TwoPairMinimum { get; } = new(
        "Two Pair Minimum",
        new Dictionary<HandCategory, int>
        {
            [HandCategory.RoyalFlush] = 250,
            [HandCategory.StraightFlush] = 50,
            [HandCategory.FourOfAKind] = 25,
            [HandCategory.FullHouse] = 9,
            [HandCategory.Flush] = 6,
            [HandCategory.Straight] = 4,
            [HandCategory.ThreeOfAKind] = 3,
            [HandCategory.TwoPair] = 2
        },
        int.MaxValue);

    public int ResolvePayout(HandEvaluation evaluation, int bet)
    {
        if (bet <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(bet), bet, "Bet must be positive.");
        }

        if (evaluation.Category == HandCategory.OnePair)
        {
            if (evaluation.PairRank is null ||
                evaluation.PairRank < MinimumPairRankForPayout ||
                !Payouts.TryGetValue(HandCategory.OnePair, out var pairMultiplier))
            {
                return 0;
            }

            return pairMultiplier * bet;
        }

        if (!Payouts.TryGetValue(evaluation.Category, out var multiplier))
        {
            return 0;
        }

        if (evaluation.Category == HandCategory.RoyalFlush && bet == MaxCoinBet)
        {
            return RoyalFlushMaxCoinPayout;
        }

        return multiplier * bet;
    }
}

public sealed record Lucky5DoubleUpOptions(
    int MaxSwitchesPerRound = 2,
    int FirstLuckyMultiplier = 4,
    int RepeatLuckyMultiplier = 2,
    int MaxCreditLimit = 40_000_000,
    bool AceCountsHiOrLo = true);

public sealed record Lucky5DoubleUpSession(
    ulong SeedRoot,
    ulong RoundSeedToken,
    CleanRoomCard[] Deck,
    int DealerIndex,
    CleanRoomCard DealerCard,
    int CurrentAmount,
    int MachineCreditBaseline,
    int CurrentRoundIndex,
    int SwitchCountInRound,
    int LuckyHitCount,
    bool IsNoLoseActive,
    Lucky5DoubleUpOptions Options,
    bool IsTerminal = false,
    Lucky5DoubleUpOutcome? TerminalOutcome = null,
    int CashoutCredits = 0);

public sealed record Lucky5DoubleUpResolution(
    BigSmallGuess Guess,
    CleanRoomCard DealerCard,
    CleanRoomCard ChallengerCard,
    Lucky5DoubleUpOutcome Outcome,
    int PreviousAmount,
    int NextAmount,
    int CashoutCredits,
    Lucky5DoubleUpSession Session);

public sealed record PresentationNoisePlan(
    int SuspenseMs,
    int RevealMs,
    int FlipFrames,
    int PulseFrames,
    int DecoySwaps);

/// <summary>
/// Externalized engine configuration for RTP rebalancing.
/// All tuning parameters in one place — see docs/REBALANCING_PLAN_85_RTP.md.
/// Rebalanced 2026-03-14 to achieve 85% RTP with preserved tension, fun, and adrenaline.
/// </summary>
public sealed record EngineConfig(
    // === Payout Scale ===
    decimal TargetRtp = 0.85m,
    decimal TargetDoubleUpRtp = 0.090m,
    decimal MinimumObservedBaseRtp = 0.3800m,
    decimal DefaultPayoutScale = 2.00m,
    decimal MinPayoutScale = 1.25m,
    decimal MaxPayoutScale = 2.35m,
    int WarmupRounds = 60,
    int ConvergenceHorizon = 250,
    decimal CorrectionGain = 1.15m,
    decimal MaxCorrection = 0.30m,
    decimal DeadZone = 0.0100m,
    int RtpSmoothingWindow = 240,
    int RtpMinSamplesForControl = 30,
    decimal MaxDriftClamp = 0.150m,
    decimal JitterAmplitude = 0.025m,
    decimal SmallTierFactor = 1.00m,
    decimal MediumTierFactor = 1.04m,
    decimal BigTierFactor = 1.08m,
    decimal WarmupOpeningSmallScale = 1.80m,
    decimal WarmupOpeningMediumScale = 1.85m,
    decimal WarmupOpeningBigScale = 1.90m,

    // === Double-Up Offer Curve ===
    decimal DoubleUpOfferFloor = 0.15m,               // ↑ from 0.08m - double-up always available
    decimal DoubleUpOfferOverTargetBand = 0.20m,      // ↑ from 0.15m - more generous when slightly hot
    decimal DoubleUpOfferTargetBand = 0.30m,          // ↑ from 0.28m - better engagement at equilibrium
    decimal DoubleUpOfferRecoveryBand = 0.50m,        // ↑ from 0.45m - stronger cold recovery
    decimal DoubleUpOfferMax = 0.65m,                 // ↑ from 0.60m - max recovery boost
    decimal DoubleUpHighDriftThreshold = 0.050m,
    decimal DoubleUpTargetUpperThreshold = 0.020m,
    decimal DoubleUpTargetLowerThreshold = -0.010m,
    decimal DoubleUpRecoveryThreshold = -0.040m,

    // === Deck Alteration Bounds ===
    int MaxColdRemovals = 1,                          // ↓ from 2 - less aggressive deck nerfing
    int MaxHotAdditions = 2,
    bool NeverRemoveFiveOfSpades = true,
    int MinDeckSize = 51,                             // ↑ from 50 - maintain more standard deck feel

    // === Streaks & Pity ===
    int StreakSoftThreshold = 4,                      // ↓ from 5 - activate pity sooner
    int StreakHardThreshold = 8,                      // ↓ from 10 - stronger intervention earlier
    int CrisisThreshold = 12,                         // ↓ from 15 - emergency boost kicks in faster
    decimal CrisisScaleBoost = 0.07m,                 // ↑ from 0.05m - stronger crisis recovery
    int MediumWinDroughtThreshold = 15,               // ↓ from 20 - address dry spells sooner
    int CooldownLength = 2,                           // ↓ from 3 - shorter neutral period after big wins

    // === Soft Caps ===
    decimal SoftCapWarning = 28_000_000m,             // ↑ from 24M - more headroom before warnings
    decimal SoftCapHard = 35_000_000m,                // ↑ from 32M - allow bigger runs
    decimal CloseThreshold = 40_000_000m,

    // === Jackpots (Replace Mode) ===
    decimal JackpotFourOfAKindCap = 1_000_000m,
    decimal JackpotFullHouseCap = 650_000m,
    decimal JackpotStraightFlushCap = 7_500_000m,
    int JackpotFourOfAKindContribution = 100,         // Reduced for 80% total RTP
    int JackpotFullHouseContribution = 80,
    int JackpotStraightFlushContribution = 180,
    decimal JackpotFourOfAKindStart = 140_000m,
    decimal JackpotFullHouseStart = 90_000m,
    decimal JackpotStraightFlushStart = 850_000m
)
{
    public static EngineConfig Default { get; } = new();

    // Computed properties for convenience
    public decimal TargetScaledBaseRtp => TargetRtp - TargetJackpotRtp - TargetDoubleUpRtp;
    public decimal TargetJackpotRtp => 0.035m;  // 3.5% from jackpots
}
