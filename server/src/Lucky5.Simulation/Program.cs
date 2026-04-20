using Lucky5.Domain.Entities;
using Lucky5.Domain.Game.CleanRoom;

// Parse command line arguments
var rounds = 10_000;
var minRtp = 0.78m;
var maxRtp = 0.82m;
var isCertificationRun = false;

for (int i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "--rounds":
            if (i + 1 < args.Length && int.TryParse(args[i + 1], out var r))
                rounds = r;
            break;
        case "--min-rtp":
            if (i + 1 < args.Length && decimal.TryParse(args[i + 1], out var min))
                minRtp = min;
            break;
        case "--max-rtp":
            if (i + 1 < args.Length && decimal.TryParse(args[i + 1], out var max))
                maxRtp = max;
            break;
        case "--certification":
            isCertificationRun = true;
            rounds = 500_000;
            break;
    }
}

const int Bet = 5_000;

var cfg = EngineConfig.Default;
var paytable = PaytableProfile.Lebanese;

Console.WriteLine("=== Lucky5 RTP Monte Carlo Simulation ===");
Console.WriteLine($"Bet: {Bet:N0} | Paytable: {paytable.Name}");
Console.WriteLine($"Target RTP: {cfg.TargetRtp:P2} = Base {cfg.TargetScaledBaseRtp:P2} + Jackpot {cfg.TargetJackpotRtp:P2} + Double-Up {cfg.TargetDoubleUpRtp:P2}");
Console.WriteLine($"Machine close threshold: {cfg.CloseThreshold:N0} | Double-up offer floor: {cfg.DoubleUpOfferFloor:P0} | Offer ceiling: {cfg.DoubleUpOfferMax:P0}");
Console.WriteLine($"Run type: {(isCertificationRun ? "Certification" : "CI Gate")} | Rounds: {rounds:N0} | RTP range: [{minRtp:P2}, {maxRtp:P2}]");
Console.WriteLine();

var balanced10kSamples = Enumerable.Range(0, 9)
    .Select(sample => RunSimulation(10_000, PlayerBehavior.Balanced, sample))
    .OrderBy(result => result.TotalRtp)
    .ToArray();
var balanced10kMedian = balanced10kSamples[balanced10kSamples.Length / 2];
var balanced100k = RunSimulation(100_000, PlayerBehavior.Balanced, 0);
var balanced1M = RunSimulation(1_000_000, PlayerBehavior.Balanced, 1);

// Run the main simulation with enhanced telemetry
var mainResult = RunSimulation(rounds, PlayerBehavior.Balanced, 0, true);

Console.WriteLine("--- Main Simulation Results ---");
PrintEnhancedSummary($"{rounds:N0} rounds", mainResult);

// Determine pass/fail based on RTP bounds
var passed = mainResult.TotalRtp >= minRtp && mainResult.TotalRtp <= maxRtp;
Console.WriteLine();
Console.WriteLine($"=== RESULT: {(passed ? "PASS" : "FAIL")} ===");
Console.WriteLine($"Final RTP: {mainResult.TotalRtp:P2} (target range: [{minRtp:P2}, {maxRtp:P2}])");

// Exit with appropriate code
Environment.Exit(passed ? 0 : 1);

SimulationResult RunSimulation(int rounds, PlayerBehavior behavior, int sampleIndex, bool enhancedTelemetry = false)
{
    var ledger = new MachineLedgerState { MachineId = 1, TargetRtp = cfg.TargetRtp };
    var session = new SessionState();
    session.StartNewSession();

    var result = new SimulationResult(behavior, rounds)
    {
        SessionsStarted = 1
    };

    for (var roundIndex = 0; roundIndex < rounds; roundIndex++)
    {
        if (session.PendingReset || session.MachineCredits < Bet * 2m)
        {
            session.StartNewSession();
            result.SessionsStarted++;
        }

        session.BeginRound();

        var seed = DeterministicSeed.FromString($"rtp-{DescribeBehavior(behavior)}-{rounds}-{sampleIndex}-{roundIndex}");
        var policyState = BuildPolicyState(ledger);
        var policyResolution = MachinePolicy.ResolvePolicy(policyState, seed);
        var policyMode = policyResolution.DistributionMode;
        
        // Track enhanced telemetry
        if (enhancedTelemetry)
        {
            if (policyResolution.Telemetry.IsWarmupActive) result.WarmupActivations++;
            if (policyResolution.Telemetry.IsPityActive) result.PityActivations++;
            if (policyResolution.Telemetry.IsCrisisActive) result.CrisisActivations++;
            result.JackpotLeakAdjustments += policyResolution.Telemetry.JackpotLeakAdjustment;
            result.DoubleUpLeakAdjustments += policyResolution.Telemetry.DoubleUpLeakAdjustment;
        }

        ledger.CapitalIn += Bet;
        ledger.RoundCount++;
        ledger.RoundsSinceMediumWin++;
        ledger.RoundsSinceLucky5Hit++;
        if (ledger.CooldownRoundsRemaining > 0)
        {
            ledger.CooldownRoundsRemaining--;
        }

        ledger.LastDistributionMode = policyMode switch
        {
            PolicyDistributionMode.Cold => DistributionMode.Cold,
            PolicyDistributionMode.Hot => DistributionMode.Hot,
            _ => DistributionMode.Neutral
        };
        ledger.ActiveFourOfAKindSlot = (ledger.RoundCount % 2 == 0) ? (int)(seed % 2) : 1 - (int)(seed % 2);
        ApplyJackpotContributions(ledger);
        ledger.NetSinceLastClose = Math.Max(ledger.CapitalIn - ledger.CapitalOut, 0m);
        session.MachineCredits -= Bet;

        ledger.CapitalIn += Bet;
        ApplyJackpotContributions(ledger);
        ledger.NetSinceLastClose = Math.Max(ledger.CapitalIn - ledger.CapitalOut, 0m);
        session.MachineCredits -= Bet;

        result.TotalIn += Bet * 2m;

        var standardDeck = FiveCardDrawEngine.BuildStandardDeck();
        var alteredDeck = MachinePolicy.AlterDeck(standardDeck, policyMode, seed, ledger.ConsecutiveLosses);
        var shuffledDeck = FiveCardDrawEngine.ShuffleDeck(seed, "hand", alteredDeck);
        var hand = shuffledDeck.Take(5).ToArray();
        var drawState = FiveCardDrawState.Create(seed, shuffledDeck, hand);
        var holdMask = ComputeOptimalHolds(hand);
        drawState = FiveCardDrawEngine.Reduce(drawState, new RoundAction(RoundActionKind.SetHoldMask, HoldMask: holdMask));
        drawState = FiveCardDrawEngine.Reduce(drawState, new RoundAction(RoundActionKind.Draw));

        var evaluation = FiveCardDrawEngine.EvaluateHand(drawState.Hand);
        var basePayout = FiveCardDrawEngine.ResolvePayout(evaluation, Bet, paytable);
        var scaleState = BuildPolicyState(ledger);
        var scaleResolution = MachinePolicy.ResolvePolicy(scaleState, seed);
        var payoutScale = scaleResolution.ForTier(MachinePolicy.ClassifyHand(evaluation.Category));
        ledger.LastPayoutScale = payoutScale;
        result.PayoutScaleSum += payoutScale;
        result.PayoutScaleSamples++;

        var scaledBasePayout = basePayout > 0
            ? (int)Math.Round(basePayout * payoutScale, MidpointRounding.AwayFromZero)
            : 0;

        var payout = scaledBasePayout;
        decimal jackpotOverlay = 0m;
        if (scaledBasePayout > 0)
        {
            ledger.CapitalOut += scaledBasePayout;
            ledger.BaseCapitalOut += basePayout;
            ledger.ConsecutiveLosses = 0;
            ledger.LastWinChannel = WinChannel.BaseGame;
            if (MachinePolicy.ClassifyHand(evaluation.Category) >= PayoutTier.Medium)
            {
                ledger.RoundsSinceMediumWin = 0;
            }

            ledger.CooldownRoundsRemaining = MachinePolicy.ComputeCooldownLength(evaluation.Category, seed);

            var jackpotWon = ResolveJackpot(ref ledger, evaluation, scaledBasePayout);
            if (jackpotWon > 0)
            {
                jackpotOverlay = jackpotWon - scaledBasePayout;
                ledger.CapitalOut += jackpotOverlay;
                ledger.JackpotCapitalOut += jackpotOverlay;
                ledger.LastWinChannel = WinChannel.Jackpot;
                payout = (int)jackpotWon;
            }
        }
        else
        {
            ledger.ConsecutiveLosses++;
            ledger.LastWinChannel = WinChannel.None;
        }

        ledger.NetSinceLastClose = Math.Max(ledger.CapitalIn - ledger.CapitalOut, 0m);

        result.ScaledBaseOut += scaledBasePayout;
        result.JackpotOverlayOut += jackpotOverlay;
        
        // Track RTP windows for enhanced telemetry
        if (enhancedTelemetry && (roundIndex + 1) % 1000 == 0)
        {
            var currentRtp = ledger.CapitalIn <= 0m ? 0m : decimal.Round((ledger.CapitalOut) / ledger.CapitalIn, 4);
            result.RtpWindows.Add(currentRtp);
        }

        if (payout > 0)
        {
            result.DirectPayingSpins++;
            if (MachinePolicy.ClassifyHand(evaluation.Category) >= PayoutTier.Medium)
            {
                result.MediumOrBetterSpins++;
            }

            result.PreDoubleUpWinCredits += payout;
            result.EligibleWinningRounds++;

            var offerState = BuildPolicyState(ledger);
            var offered = MachinePolicy.ShouldOfferDoubleUp(offerState, seed);
            if (offered)
            {
                result.OfferedWinningRounds++;
            }

            if (offered && ShouldEnterDoubleUp(behavior, seed, payout, session.MachineCredits))
            {
                result.EnteredDoubleUpChains++;
                result.EnteredTriggerCredits += payout;

                var chainResult = PlayDoubleUpChain(seed, policyMode, behavior, session, payout, result);
                result.DoubleUpOverlayOut += chainResult.Delta;
                ledger.CapitalOut += chainResult.Delta;
                ledger.DoubleUpCapitalOut += chainResult.Delta;
                ledger.LastWinChannel = chainResult.Delta > 0m ? WinChannel.DoubleUp : ledger.LastWinChannel;

                if (chainResult.ContinuedAfterTakeHalf && session.MachineCredits >= 50_000_000m)
                {
                    result.Over50MViaTakeHalfContinuation++;
                }
            }
            else
            {
                BankCredits(session, payout, result);
            }
        }

        if (!session.PendingReset && ShouldCashOutSession(behavior, session))
        {
            session.PendingReset = true;
        }
    }

    result.FinalObservedRtp = ledger.ObservedRtp;
    result.FinalBaseRtp = ledger.CapitalIn <= 0m ? 0m : decimal.Round(result.ScaledBaseOut / ledger.CapitalIn, 4);
    result.FinalJackpotRtp = ledger.CapitalIn <= 0m ? 0m : decimal.Round(result.JackpotOverlayOut / ledger.CapitalIn, 4);
    result.FinalDoubleUpRtp = ledger.CapitalIn <= 0m ? 0m : decimal.Round(result.DoubleUpOverlayOut / ledger.CapitalIn, 4);
    return result;
}

static MachinePolicyState BuildPolicyState(MachineLedgerState ledger) => new()
{
    CreditsIn = ledger.CapitalIn,
    CreditsOut = ledger.CapitalOut,
    BaseCreditsOut = ledger.BaseCapitalOut,
    JackpotCreditsOut = ledger.JackpotCapitalOut,
    DoubleUpCreditsOut = ledger.DoubleUpCapitalOut,
    TargetRtp = ledger.TargetRtp,
    RoundCount = ledger.RoundCount,
    ConsecutiveLosses = ledger.ConsecutiveLosses,
    RoundsSinceMediumWin = ledger.RoundsSinceMediumWin,
    CooldownRoundsRemaining = ledger.CooldownRoundsRemaining,
    NetSinceLastClose = ledger.NetSinceLastClose,
    RoundsSinceLucky5Hit = ledger.RoundsSinceLucky5Hit
};

decimal ResolveJackpot(ref MachineLedgerState ledger, HandEvaluation evaluation, int scaledBasePayout)
{
    if (evaluation.Category == HandCategory.FullHouse
        && evaluation.Tiebreak[0] == ledger.JackpotFullHouseRank
        && ledger.JackpotFullHouse > scaledBasePayout)
    {
        var jackpot = ledger.JackpotFullHouse;
        ledger.JackpotFullHouse = cfg.JackpotFullHouseStart;
        return jackpot;
    }

    if (evaluation.Category == HandCategory.FourOfAKind && ledger.ActiveFourOfAKindSlot == 0 && ledger.JackpotFourOfAKindA > scaledBasePayout)
    {
        var jackpot = ledger.JackpotFourOfAKindA;
        ledger.JackpotFourOfAKindA = cfg.JackpotFourOfAKindStart;
        return jackpot;
    }

    if (evaluation.Category == HandCategory.FourOfAKind && ledger.ActiveFourOfAKindSlot == 1 && ledger.JackpotFourOfAKindB > scaledBasePayout)
    {
        var jackpot = ledger.JackpotFourOfAKindB;
        ledger.JackpotFourOfAKindB = cfg.JackpotFourOfAKindStart;
        return jackpot;
    }

    if (evaluation.Category == HandCategory.StraightFlush && ledger.JackpotStraightFlush > scaledBasePayout)
    {
        var jackpot = ledger.JackpotStraightFlush;
        ledger.JackpotStraightFlush = cfg.JackpotStraightFlushStart;
        return jackpot;
    }

    return 0m;
}

DoubleUpChainResult PlayDoubleUpChain(
    ulong roundSeed,
    PolicyDistributionMode policyMode,
    PlayerBehavior behavior,
    SessionState bank,
    int openingAmount,
    SimulationResult result)
{
    var duDeck = MachinePolicy.BuildDoubleUpDeck(
        FiveCardDrawEngine.BuildStandardDeck(),
        roundSeed,
        0,
        0m,
        policyMode);

    var session = Lucky5DoubleUpEngine.CreateSessionFromDeck(
        roundSeed,
        FiveCardDrawEngine.ShuffleDeck(roundSeed, "double-up", duDeck),
        openingAmount,
        machineCreditBaseline: Decimal.ToInt32(Math.Min(bank.MachineCredits, int.MaxValue)),
        options: new Lucky5DoubleUpOptions(MaxCreditLimit: Decimal.ToInt32(cfg.CloseThreshold)));

    var settledCredits = 0;
    var continuedAfterTakeHalf = false;
    var takeHalfUsed = false;

    for (var step = 0; step < 16; step++)
    {
        if (!takeHalfUsed && ShouldTakeHalf(behavior, roundSeed, step, openingAmount, bank.MachineCredits, session.CurrentAmount))
        {
            var half = session.CurrentAmount / 2;
            var remaining = session.CurrentAmount - half;
            settledCredits += half;
            BankCredits(bank, half, result);
            session = session with { CurrentAmount = remaining };
            takeHalfUsed = true;
        }

        if (ShouldCashoutDoubleUp(behavior, roundSeed, step, openingAmount, bank.PendingReset, takeHalfUsed, bank.MachineCredits, session.CurrentAmount))
        {
            settledCredits += session.CurrentAmount;
            BankCredits(bank, session.CurrentAmount, result);
            return new DoubleUpChainResult(settledCredits - openingAmount, takeHalfUsed && continuedAfterTakeHalf);
        }

        while (session.SwitchCountInRound < session.Options.MaxSwitchesPerRound
            && ShouldSwitchDealer(behavior, roundSeed, step, session))
        {
            session = Lucky5DoubleUpEngine.SwitchDealer(session);
            if (session.DealerCard.Rank == 5 && session.DealerCard.Suit == 'S')
            {
                result.LuckySwitchHits++;
            }

            if (takeHalfUsed)
            {
                continuedAfterTakeHalf = true;
            }

            if (!ShouldSwitchDealer(behavior, roundSeed, step + session.SwitchCountInRound, session))
            {
                break;
            }
        }

        var resolution = Lucky5DoubleUpEngine.ResolveGuess(session, ChooseGuess(session));
        if (takeHalfUsed)
        {
            continuedAfterTakeHalf = true;
        }

        switch (resolution.Outcome)
        {
            case Lucky5DoubleUpOutcome.Win:
                result.DoubleUpResolutionWins++;
                session = resolution.Session;
                continue;

            case Lucky5DoubleUpOutcome.MachineClosed:
                result.DoubleUpResolutionWins++;
                settledCredits += resolution.CashoutCredits;
                BankCredits(bank, resolution.CashoutCredits, result);
                return new DoubleUpChainResult(settledCredits - openingAmount, takeHalfUsed && continuedAfterTakeHalf);

            case Lucky5DoubleUpOutcome.SafeFail:
                result.DoubleUpResolutionLosses++;
                settledCredits += resolution.CashoutCredits;
                BankCredits(bank, resolution.CashoutCredits, result);
                return new DoubleUpChainResult(settledCredits - openingAmount, takeHalfUsed && continuedAfterTakeHalf);

            default:
                result.DoubleUpResolutionLosses++;
                return new DoubleUpChainResult(settledCredits - openingAmount, takeHalfUsed && continuedAfterTakeHalf);
        }
    }

    settledCredits += session.CurrentAmount;
    BankCredits(bank, session.CurrentAmount, result);
    return new DoubleUpChainResult(settledCredits - openingAmount, takeHalfUsed && continuedAfterTakeHalf);
}

void BankCredits(SessionState bank, int amount, SimulationResult result)
{
    if (amount <= 0)
    {
        return;
    }

    var before = bank.MachineCredits;
    bank.MachineCredits += amount;
    if (!bank.PendingReset && before < cfg.CloseThreshold && bank.MachineCredits >= cfg.CloseThreshold)
    {
        bank.PendingReset = true;
        result.MachineCloses40M++;
    }
}

static bool ShouldEnterDoubleUp(PlayerBehavior behavior, ulong seed, int payout, decimal machineCredits)
{
    return behavior switch
    {
        PlayerBehavior.ConservativeCollectFirst => false,
        PlayerBehavior.Balanced => machineCredits + payout < EngineConfig.Default.CloseThreshold
            && Roll(seed, "accept-balanced", payout, 0.78m),
        PlayerBehavior.AggressiveCabinetClosing => machineCredits + payout < 50_000_000m || payout < 2_000_000,
        _ => false
    };
}

static bool ShouldTakeHalf(PlayerBehavior behavior, ulong seed, int step, int openingAmount, decimal machineCredits, int currentAmount)
{
    return behavior switch
    {
        PlayerBehavior.Balanced => currentAmount >= Math.Max(openingAmount * 4, 500_000)
            && machineCredits + currentAmount < EngineConfig.Default.CloseThreshold
            && Roll(seed, "take-half-balanced", step, 0.35m),
        PlayerBehavior.AggressiveCabinetClosing => currentAmount >= Math.Max(openingAmount * 8, 1_000_000)
            && machineCredits + currentAmount >= EngineConfig.Default.CloseThreshold * 0.65m
            && Roll(seed, "take-half-aggressive", step, 0.60m),
        _ => false
    };
}

static bool ShouldCashoutDoubleUp(
    PlayerBehavior behavior,
    ulong seed,
    int step,
    int openingAmount,
    bool machineAlreadyClosed,
    bool takeHalfUsed,
    decimal machineCredits,
    int currentAmount)
{
    if (machineAlreadyClosed && behavior != PlayerBehavior.AggressiveCabinetClosing)
    {
        return true;
    }

    return behavior switch
    {
        PlayerBehavior.Balanced => step > 0 && (
            takeHalfUsed
            || currentAmount >= Math.Max(openingAmount * 2, 250_000)
            || Roll(seed, "cashout-balanced", step, 0.70m)),
        PlayerBehavior.AggressiveCabinetClosing => (machineCredits + currentAmount >= EngineConfig.Default.CloseThreshold && step > 0)
            || currentAmount >= Math.Max(openingAmount * 32, 8_000_000)
            || step >= 7,
        _ => true
    };
}

static bool ShouldSwitchDealer(PlayerBehavior behavior, ulong seed, int step, Lucky5DoubleUpSession session)
{
    var dealerRank = session.DealerCard.Rank;
    return behavior switch
    {
        PlayerBehavior.Balanced => session.SwitchCountInRound == 0
            && dealerRank is 7 or 8
            && Roll(seed, "switch-balanced", step, 0.25m),
        PlayerBehavior.AggressiveCabinetClosing => dealerRank is >= 6 and <= 9
            && Roll(seed, "switch-aggressive", step + session.SwitchCountInRound, session.SwitchCountInRound == 0 ? 0.60m : 0.35m),
        _ => false
    };
}

static bool ShouldCashOutSession(PlayerBehavior behavior, SessionState session)
{
    return behavior switch
    {
        PlayerBehavior.ConservativeCollectFirst => session.MachineCredits >= session.SessionCashIn * 2m,
        PlayerBehavior.Balanced => session.MachineCredits >= Math.Max(session.SessionCashIn * 2.5m, 2_000_000m)
            && session.MachineCredits < EngineConfig.Default.CloseThreshold * 0.85m,
        _ => false
    };
}

static BigSmallGuess ChooseGuess(Lucky5DoubleUpSession session)
    => session.DealerCard.Rank <= 8 ? BigSmallGuess.Big : BigSmallGuess.Small;

static bool Roll(ulong seed, string stream, int salt, decimal threshold)
{
    var rng = new SplitMix64Rng(DeterministicSeed.Derive(seed, stream, salt));
    return (decimal)rng.NextUnit() < threshold;
}

bool[] ComputeOptimalHolds(CleanRoomCard[] hand)
{
    var eval = FiveCardDrawEngine.EvaluateHand(hand);
    var holds = new bool[5];

    switch (eval.Category)
    {
        case HandCategory.RoyalFlush:
        case HandCategory.StraightFlush:
        case HandCategory.FourOfAKind:
        case HandCategory.FullHouse:
        case HandCategory.Flush:
        case HandCategory.Straight:
            return [true, true, true, true, true];

        case HandCategory.ThreeOfAKind:
        {
            var tripRank = hand.GroupBy(c => c.Rank).First(g => g.Count() == 3).Key;
            for (var index = 0; index < 5; index++) holds[index] = hand[index].Rank == tripRank;
            return holds;
        }

        case HandCategory.TwoPair:
        {
            var pairRanks = hand.GroupBy(c => c.Rank).Where(g => g.Count() == 2).Select(g => g.Key).ToHashSet();
            for (var index = 0; index < 5; index++) holds[index] = pairRanks.Contains(hand[index].Rank);
            return holds;
        }

        case HandCategory.OnePair:
        {
            var pairRank = hand.GroupBy(c => c.Rank).First(g => g.Count() == 2).Key;
            for (var index = 0; index < 5; index++) holds[index] = hand[index].Rank == pairRank;
            return holds;
        }

        default:
            return [false, false, false, false, false];
    }
}

void ApplyJackpotContributions(MachineLedgerState ledger)
{
    // Only the currently-starred Four-of-a-Kind jackpot accrues this round,
    // mirroring GameService.ApplyJackpotContributions so the simulation
    // reflects production jackpot dynamics faithfully.
    if (ledger.ActiveFourOfAKindSlot == 0)
    {
        ledger.JackpotFourOfAKindA = Math.Min(ledger.JackpotFourOfAKindA + cfg.JackpotFourOfAKindContribution, cfg.JackpotFourOfAKindCap);
    }
    else
    {
        ledger.JackpotFourOfAKindB = Math.Min(ledger.JackpotFourOfAKindB + cfg.JackpotFourOfAKindContribution, cfg.JackpotFourOfAKindCap);
    }
    ledger.JackpotFullHouse = Math.Min(ledger.JackpotFullHouse + cfg.JackpotFullHouseContribution, cfg.JackpotFullHouseCap);
    ledger.JackpotStraightFlush = Math.Min(ledger.JackpotStraightFlush + cfg.JackpotStraightFlushContribution, cfg.JackpotStraightFlushCap);
}

static void PrintSummary(string label, SimulationResult result)
{
    Console.WriteLine($"{label,-32} | RTP {result.TotalRtp:P2} | Base {result.BaseRtp:P2} | Jackpot {result.JackpotRtp:P2} | DU {result.DoubleUpRtp:P2}");
    Console.WriteLine($"  Paying spins {result.DirectPayingSpinFrequency:P2} | Medium+ {result.MediumOrBetterFrequency:P2} | DU offer/win {result.OfferRateOnWinningRounds:P2} | Accept {result.AcceptRate:P2}");
    Console.WriteLine($"  Entered DU gain {result.RealizedIncrementalGainPerEnteredChain:P2} of trigger win | Avg scale {result.AveragePayoutScale:F3} | 40M closes {result.MachineCloses40M:N0} | 50M take-half+continue {result.Over50MViaTakeHalfContinuation:N0}");
}

static void PrintEnhancedSummary(string label, SimulationResult result)
{
    Console.WriteLine($"{label,-32} | RTP {result.TotalRtp:P2} | Base {result.BaseRtp:P2} | Jackpot {result.JackpotRtp:P2} | DU {result.DoubleUpRtp:P2}");
    Console.WriteLine($"  Paying spins {result.DirectPayingSpinFrequency:P2} | Medium+ {result.MediumOrBetterFrequency:P2} | DU offer/win {result.OfferRateOnWinningRounds:P2} | Accept {result.AcceptRate:P2}");
    Console.WriteLine($"  Entered DU gain {result.RealizedIncrementalGainPerEnteredChain:P2} of trigger win | Avg scale {result.AveragePayoutScale:F3} | 40M closes {result.MachineCloses40M:N0} | 50M take-half+continue {result.Over50MViaTakeHalfContinuation:N0}");
    
    // Enhanced telemetry
    Console.WriteLine($"  Warmup activations: {result.WarmupActivations:N0} | Pity activations: {result.PityActivations:N0} | Crisis activations: {result.CrisisActivations:N0}");
    Console.WriteLine($"  Jackpot leak adjustments: {result.JackpotLeakAdjustments:F4} | Double-up leak adjustments: {result.DoubleUpLeakAdjustments:F4}");
    
    // RTP windows (1k, 5k, 50k if available)
    if (result.RtpWindows.Count > 0)
    {
        var window1k = result.RtpWindows.Count >= 1 ? result.RtpWindows[0] : 0m;
        var window5k = result.RtpWindows.Count >= 5 ? result.RtpWindows[4] : 0m;
        var window50k = result.RtpWindows.Count >= 50 ? result.RtpWindows[49] : 0m;
        Console.WriteLine($"  RTP windows: 1k {window1k:P2} | 5k {window5k:P2} | 50k {window50k:P2}");
    }
}

static string DescribeBehavior(PlayerBehavior behavior) => behavior switch
{
    PlayerBehavior.ConservativeCollectFirst => "Conservative collect-first",
    PlayerBehavior.Balanced => "Balanced",
    PlayerBehavior.AggressiveCabinetClosing => "Aggressive cabinet-closing",
    _ => behavior.ToString()
};

enum PlayerBehavior
{
    ConservativeCollectFirst = 0,
    Balanced = 1,
    AggressiveCabinetClosing = 2
}

sealed class SessionState
{
    private const decimal DefaultStartingSessionCredits = 1_000_000m;

    public decimal MachineCredits { get; set; }
    public decimal SessionCashIn { get; set; }
    public bool PendingReset { get; set; }

    public void StartNewSession()
    {
        MachineCredits = DefaultStartingSessionCredits;
        SessionCashIn = DefaultStartingSessionCredits;
        PendingReset = false;
    }

    public void BeginRound()
    {
        // No-op placeholder for symmetry with the live flow.
    }
}

sealed class SimulationResult(PlayerBehavior behavior, int rounds)
{
    public PlayerBehavior Behavior { get; } = behavior;
    public int Rounds { get; } = rounds;
    public decimal TotalIn { get; set; }
    public decimal ScaledBaseOut { get; set; }
    public decimal JackpotOverlayOut { get; set; }
    public decimal DoubleUpOverlayOut { get; set; }
    public decimal PreDoubleUpWinCredits { get; set; }
    public decimal EnteredTriggerCredits { get; set; }
    public decimal PayoutScaleSum { get; set; }
    public int PayoutScaleSamples { get; set; }
    public int DirectPayingSpins { get; set; }
    public int MediumOrBetterSpins { get; set; }
    public int EligibleWinningRounds { get; set; }
    public int OfferedWinningRounds { get; set; }
    public int EnteredDoubleUpChains { get; set; }
    public int DoubleUpResolutionWins { get; set; }
    public int DoubleUpResolutionLosses { get; set; }
    public int LuckySwitchHits { get; set; }
    public int MachineCloses40M { get; set; }
    public int Over50MViaTakeHalfContinuation { get; set; }
    public int SessionsStarted { get; set; }
    public decimal FinalObservedRtp { get; set; }
    public decimal FinalBaseRtp { get; set; }
    public decimal FinalJackpotRtp { get; set; }
    public decimal FinalDoubleUpRtp { get; set; }
    
    // Enhanced telemetry fields
    public int WarmupActivations { get; set; }
    public int PityActivations { get; set; }
    public int CrisisActivations { get; set; }
    public decimal JackpotLeakAdjustments { get; set; }
    public decimal DoubleUpLeakAdjustments { get; set; }
    public List<decimal> RtpWindows { get; set; } = new();

    public decimal TotalRtp => TotalIn <= 0m ? 0m : decimal.Round((ScaledBaseOut + JackpotOverlayOut + DoubleUpOverlayOut) / TotalIn, 4);
    public decimal BaseRtp => TotalIn <= 0m ? 0m : decimal.Round(ScaledBaseOut / TotalIn, 4);
    public decimal JackpotRtp => TotalIn <= 0m ? 0m : decimal.Round(JackpotOverlayOut / TotalIn, 4);
    public decimal DoubleUpRtp => TotalIn <= 0m ? 0m : decimal.Round(DoubleUpOverlayOut / TotalIn, 4);
    public decimal DirectPayingSpinFrequency => Rounds <= 0 ? 0m : decimal.Round((decimal)DirectPayingSpins / Rounds, 4);
    public decimal MediumOrBetterFrequency => Rounds <= 0 ? 0m : decimal.Round((decimal)MediumOrBetterSpins / Rounds, 4);
    public decimal OfferRateOnWinningRounds => EligibleWinningRounds <= 0 ? 0m : decimal.Round((decimal)OfferedWinningRounds / EligibleWinningRounds, 4);
    public decimal AcceptRate => OfferedWinningRounds <= 0 ? 0m : decimal.Round((decimal)EnteredDoubleUpChains / OfferedWinningRounds, 4);
    public decimal RealizedIncrementalGainPerEnteredChain => EnteredTriggerCredits <= 0m ? 0m : decimal.Round(DoubleUpOverlayOut / EnteredTriggerCredits, 4);
    public decimal AveragePayoutScale => PayoutScaleSamples <= 0 ? 0m : decimal.Round(PayoutScaleSum / PayoutScaleSamples, 4);
}

readonly record struct DoubleUpChainResult(decimal Delta, bool ContinuedAfterTakeHalf);
