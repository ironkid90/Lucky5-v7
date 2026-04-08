namespace Lucky5.Infrastructure.Services;

using Lucky5.Application.Contracts;
using Lucky5.Application.Dtos;
using Lucky5.Application.Requests;
using Lucky5.Domain.Entities;
using Lucky5.Domain.Game.CleanRoom;
using Lucky5.Application.Interfaces;
using Lucky5.Infrastructure.Persistence;

public sealed class GameService(IDataStore store, IEntropyGenerator entropyGenerator, IMachineStateCache stateCache, IPersistentStateCoordinator? persistentStateCoordinator = null) : IGameService
{
    private const decimal CashInUnit = 200_000m;
    private const decimal MaxSessionCashIn = 1_000_000m;
    private static readonly EngineConfig EngineCfg = EngineConfig.Default;
    private static readonly decimal MachineCloseCredits = EngineCfg.CloseThreshold;
    private static readonly IReadOnlyList<OfferDto> DefaultOffers =
    [
        new(1, "Welcome Bonus", "First deposit bonus", 10),
        new(2, "Weekend Cashback", "5% cashback on losses", 5)
    ];

    private static readonly Dictionary<string, decimal> Rules = new(StringComparer.OrdinalIgnoreCase)
    {
        ["RoyalFlush"] = 1000,
        ["StraightFlush"] = 75,
        ["FourOfAKind"] = 15,
        ["FullHouse"] = 12,
        ["Flush"] = 10,
        ["Straight"] = 8,
        ["ThreeOfAKind"] = 3,
        ["TwoPair"] = 2
    };

    public Task<IReadOnlyList<string>> GetGamesAsync(CancellationToken cancellationToken)
        => Task.FromResult<IReadOnlyList<string>>(["Lucky5", "VideoPoker"]);

    public async Task<IReadOnlyList<MachineListingDto>> GetMachinesAsync(CancellationToken cancellationToken)
        => (await store.GetMachinesAsync())
            .Select(x => new MachineListingDto(x.Id, x.Name, x.IsOpen, x.MinBet, x.MaxBet))
            .ToArray();

    public Task<DefaultRulesDto> GetDefaultRulesAsync(CancellationToken cancellationToken)
        => Task.FromResult(new DefaultRulesDto(new Dictionary<string, decimal>(Rules)));

    public async Task<IReadOnlyList<OfferDto>> GetOffersAsync(CancellationToken cancellationToken)
    {
        var offers = await store.GetOffersAsync();
        if (offers.Count == 0)
        {
            return DefaultOffers;
        }

        return offers
            .Select(x => new OfferDto(x.Id, x.Title, x.Description, x.BonusAmount))
            .ToArray();
    }

    public async Task<MachineSessionDto> GetMachineSessionAsync(Guid userId, int machineId, CancellationToken cancellationToken)
    {
        var cachedSession = await stateCache.GetMachineSessionAsync(userId, machineId);
        if (cachedSession is not null)
            return cachedSession;

        var profile = await RequireProfileAsync(userId);
        await RequireMachineAsync(machineId);
        var session = await RequireMachineSessionAsync(userId, machineId, createIfMissing: true);
        var dto = await ToMachineSessionDtoAsync(userId, session, profile.WalletBalance);
        stateCache.SetMachineSession(userId, machineId, dto);
        return dto;
    }

    public async Task<MachineSessionDto> CashInAsync(Guid userId, int machineId, decimal amount, CancellationToken cancellationToken)
    {
        var profile = await RequireProfileAsync(userId);
        await RequireMachineAsync(machineId);
        var session = await RequireMachineSessionAsync(userId, machineId, createIfMissing: true);

        if (amount < CashInUnit || amount > MaxSessionCashIn || amount % CashInUnit != 0)
            throw new InvalidOperationException("Cash in must be in 200,000 increments up to 1,000,000");
        if (session.TotalCashIn + amount > MaxSessionCashIn)
            throw new InvalidOperationException("Maximum session cash-in is 1,000,000");
        if (profile.WalletBalance < amount)
            throw new InvalidOperationException("Insufficient wallet balance");

        profile.WalletBalance -= amount;
        session.MachineCredits += amount;
        session.TotalCashIn += amount;
        session.LastUpdatedUtc = DateTime.UtcNow;
        session.IsMachineClosed = session.MachineCredits >= MachineCloseCredits;

        await store.UpdateMachineSessionAsync(session);
        
        await store.AddWalletLedgerEntryAsync(new WalletLedgerEntry
        {
            UserId = userId,
            Amount = -amount,
            TransactionType = "MachineCashIn",
            ReferenceId = $"machine:{machineId}:cashin",
            BalanceAfter = profile.WalletBalance,
            CreatedUtc = DateTime.UtcNow
        });

        await store.UpdateProfileAsync(profile);

        stateCache.InvalidateMachineSession(userId, machineId);
        return await ToMachineSessionDtoAsync(userId, session, profile.WalletBalance);
    }

    public async Task<MachineSessionDto> CashOutAsync(Guid userId, int machineId, CancellationToken cancellationToken)
    {
        var profile = await RequireProfileAsync(userId);
        var session = await RequireMachineSessionAsync(userId, machineId, createIfMissing: false);

        if (session.MachineCredits <= 0m)
        {
            return await ToMachineSessionDtoAsync(userId, session, profile.WalletBalance);
        }

        if (await HasRecoverableRoundAsync(userId, machineId))
            throw new InvalidOperationException("Finish the current round before cashing out");
        if (!CanCashOut(session))
            throw new InvalidOperationException("Cash out is only available when the machine is closed or credits reach the 2x session threshold");

        var amount = session.MachineCredits;
        profile.WalletBalance += amount;
        session.MachineCredits = 0m;
        session.TotalCashIn = 0m;
        session.IsMachineClosed = false;
        session.LastUpdatedUtc = DateTime.UtcNow;

        await store.UpdateMachineSessionAsync(session);
        await store.UpdateProfileAsync(profile);

        await store.AddWalletLedgerEntryAsync(new WalletLedgerEntry
        {
            UserId = userId,
            Amount = amount,
            TransactionType = "MachineCashOut",
            ReferenceId = $"machine:{machineId}:cashout",
            BalanceAfter = profile.WalletBalance,
            CreatedUtc = DateTime.UtcNow
        });

        stateCache.InvalidateMachineSession(userId, machineId);
        return await ToMachineSessionDtoAsync(userId, session, profile.WalletBalance);
    }

    public async Task<DealResultDto> DealAsync(Guid userId, DealRequest request, CancellationToken cancellationToken)
    {
        var machine = await RequireMachineAsync(request.MachineId);
        var session = await RequireMachineSessionAsync(userId, request.MachineId, createIfMissing: true);
        
        if (session.IsMachineClosed)
            throw new InvalidOperationException("Machine is closed - cash out to wallet before continuing");
        if (request.BetAmount <= 0 || request.BetAmount < machine.MinBet || request.BetAmount > machine.MaxBet)
            throw new InvalidOperationException("Bet amount is outside machine limits");
        if (session.MachineCredits < request.BetAmount * 2m)
            throw new InvalidOperationException("Insufficient machine credits for deal and draw - cash in from wallet first");

        ulong seed;
        int active4kSlot;
        PolicyDistributionMode policyMode;
        MachinePolicyState policyState;
        
        var ledger = await RequireMachineLedgerAsync(machine.Id);
        
        seed = entropyGenerator.CreateSeed(userId, machine.Id, request.BetAmount, ledger);
        policyState = BuildMachinePolicyState(ledger);
        
        var policyResolution = MachinePolicy.ResolvePolicy(policyState, seed);
        policyMode = policyResolution.DistributionMode;
        if (session.CounterplayScore >= 3 && policyMode == PolicyDistributionMode.Cold)
        {
            policyMode = PolicyDistributionMode.Neutral;
        }
        
        ledger.CapitalIn += request.BetAmount;
        ledger.RoundCount++;
        ledger.RoundsSinceMediumWin++;
        ledger.RoundsSinceLucky5Hit++;
        if (ledger.CooldownRoundsRemaining > 0) ledger.CooldownRoundsRemaining--;
        ledger.LastRoundUtc = DateTime.UtcNow;
        ledger.LastDistributionMode = policyMode switch
        {
            PolicyDistributionMode.Cold => DistributionMode.Cold,
            PolicyDistributionMode.Hot => DistributionMode.Hot,
            _ => DistributionMode.Neutral
        };
        active4kSlot = (ledger.RoundCount % 2 == 0) ? (int)(seed % 2) : 1 - (int)(seed % 2);
        ledger.ActiveFourOfAKindSlot = active4kSlot;
        ApplyJackpotContributions(ledger, EngineCfg);
        ledger.NetSinceLastClose = Math.Max(ledger.CapitalIn - ledger.CapitalOut, 0m);

        await store.UpdateMachineLedgerAsync(ledger);

        var standardDeck = FiveCardDrawEngine.BuildStandardDeck();
        var alteredDeck = MachinePolicy.AlterDeck(standardDeck, policyMode, seed, policyState.ConsecutiveLosses);
        var shuffledDeck = FiveCardDrawEngine.ShuffleDeck(seed, "hand", alteredDeck);
        var hand = shuffledDeck.Take(5).ToArray();
        var drawState = FiveCardDrawState.Create(seed, shuffledDeck, hand);

        session.MachineCredits -= request.BetAmount;
        session.LastUpdatedUtc = DateTime.UtcNow;
        await store.UpdateMachineSessionAsync(session);

        var cards = hand.Select(c => c.ToLegacyPokerCard()).ToList();

        var round = new GameRound
        {
            UserId = userId,
            MachineId = request.MachineId,
            BetAmount = request.BetAmount,
            InitialCards = cards,
            FinalCards = cards,
            PolicyMode = policyMode,
            RoundEntropySeed = seed,
            CleanRoomState = drawState,
            ActiveFourOfAKindSlotAtDeal = active4kSlot
        };

        await store.SaveRoundAsync(round);

        var profile = await RequireProfileAsync(userId);
        await store.AddWalletLedgerEntryAsync(new WalletLedgerEntry
        {
            UserId = userId,
            Amount = -request.BetAmount,
            TransactionType = "Bet",
            ReferenceId = round.RoundId.ToString("N"),
            BalanceAfter = profile.WalletBalance, // Technically wallet doesn't change here, just reference
            CreatedUtc = DateTime.UtcNow
        });

        var jackpots = SnapshotJackpots(ledger);
        var advisedHolds = FiveCardDrawEngine.ComputeAdvisedHolds(hand);

        stateCache.InvalidateActiveRound(userId, request.MachineId);
        stateCache.InvalidateMachineSession(userId, request.MachineId);
        return new DealResultDto(round.RoundId, cards.Select(ToDto).ToArray(), request.BetAmount, session.MachineCredits, jackpots, advisedHolds);
    }

    public async Task<DrawResultDto> DrawAsync(Guid userId, DrawRequest request, CancellationToken cancellationToken)
    {
        var round = await store.GetRoundAsync(request.RoundId);
        if (round == null || round.UserId != userId)
            throw new KeyNotFoundException("Round not found");
        if (round.IsCompleted)
            throw new InvalidOperationException("Round already completed");
        if (round.CleanRoomState is null)
            throw new InvalidOperationException("Clean-room state not initialized");
        if (round.CleanRoomState.Phase != RoundPhase.Dealt)
            throw new InvalidOperationException("Draw already completed for this round");

        var session = await RequireMachineSessionAsync(userId, round.MachineId, createIfMissing: false);
        if (session.IsMachineClosed)
            throw new InvalidOperationException("Machine is closed - cash out to wallet before continuing");
        if (session.MachineCredits < round.BetAmount)
            throw new InvalidOperationException("Not enough machine credits for draw");

        session.MachineCredits -= round.BetAmount;
        session.LastUpdatedUtc = DateTime.UtcNow;

        var ledger = await RequireMachineLedgerAsync(round.MachineId);
        ledger.CapitalIn += round.BetAmount;
        ApplyJackpotContributions(ledger, EngineCfg);
        ledger.NetSinceLastClose = Math.Max(ledger.CapitalIn - ledger.CapitalOut, 0m);

        await store.UpdateMachineLedgerAsync(ledger);
        
        var profile = await RequireProfileAsync(userId);
        await store.AddWalletLedgerEntryAsync(new WalletLedgerEntry
        {
            UserId = userId,
            Amount = -round.BetAmount,
            BalanceAfter = session.MachineCredits, // Represents machine credits context here
            TransactionType = "DrawBet",
            ReferenceId = round.RoundId.ToString("N"),
            CreatedUtc = DateTime.UtcNow
        });

        var holdMask = new bool[5];
        foreach (var idx in request.HoldIndexes)
            if (idx >= 0 && idx < 5)
                holdMask[idx] = true;

        UpdateCounterplay(session, AssessCounterplay(round.CleanRoomState.Hand, request.HoldIndexes));

        var state = FiveCardDrawEngine.Reduce(round.CleanRoomState, new RoundAction(RoundActionKind.SetHoldMask, HoldMask: holdMask));
        state = FiveCardDrawEngine.Reduce(state, new RoundAction(RoundActionKind.Draw));

        var evaluation = FiveCardDrawEngine.EvaluateHand(state.Hand);
        var basePayout = FiveCardDrawEngine.ResolvePayout(evaluation, (int)round.BetAmount);

        decimal payoutScale;
        
        var scaleState = BuildMachinePolicyState(ledger);
        var policyResolution = MachinePolicy.ResolvePolicy(scaleState, round.RoundEntropySeed);
        payoutScale = policyResolution.ForTier(MachinePolicy.ClassifyHand(evaluation.Category));
        ledger.LastPayoutScale = payoutScale;

        var payout = basePayout > 0 ? (int)Math.Round(basePayout * payoutScale, MidpointRounding.AwayFromZero) : 0;
        var handRankName = MapHandCategory(evaluation);
        var finalCards = state.Hand.Select(c => c.ToLegacyPokerCard()).ToList();

        round.FinalCards = finalCards;
        round.HandRank = handRankName;
        round.WinAmount = payout;
        round.IsCompleted = true;
        round.CleanRoomState = state;
        round.DrawAttempts++;

        decimal jackpotWon = 0;
        if (payout > 0)
        {
            ledger.CapitalOut += payout;
            ledger.BaseCapitalOut += basePayout;
            ledger.ConsecutiveLosses = 0;
            ledger.LastWinChannel = WinChannel.BaseGame;
            if (MachinePolicy.ClassifyHand(evaluation.Category) >= PayoutTier.Medium)
                ledger.RoundsSinceMediumWin = 0;
            ledger.CooldownRoundsRemaining = MachinePolicy.ComputeCooldownLength(evaluation.Category, round.RoundEntropySeed);

            if (evaluation.Category == HandCategory.FullHouse
                && evaluation.Tiebreak[0] == ledger.JackpotFullHouseRank
                && ledger.JackpotFullHouse > payout)
            {
                jackpotWon = ledger.JackpotFullHouse;
                ledger.JackpotFullHouse = EngineCfg.JackpotFullHouseStart;
            }
            else if (evaluation.Category == HandCategory.FourOfAKind && round.ActiveFourOfAKindSlotAtDeal == 0 && ledger.JackpotFourOfAKindA > payout)
            {
                jackpotWon = ledger.JackpotFourOfAKindA;
                ledger.JackpotFourOfAKindA = EngineCfg.JackpotFourOfAKindStart;
            }
            else if (evaluation.Category == HandCategory.FourOfAKind && round.ActiveFourOfAKindSlotAtDeal == 1 && ledger.JackpotFourOfAKindB > payout)
            {
                jackpotWon = ledger.JackpotFourOfAKindB;
                ledger.JackpotFourOfAKindB = EngineCfg.JackpotFourOfAKindStart;
            }
            else if (evaluation.Category == HandCategory.StraightFlush && ledger.JackpotStraightFlush > payout)
            {
                jackpotWon = ledger.JackpotStraightFlush;
                ledger.JackpotStraightFlush = EngineCfg.JackpotStraightFlushStart;
            }

            if (jackpotWon > 0)
            {
                var netJackpot = jackpotWon - payout;
                ledger.CapitalOut += netJackpot;
                ledger.JackpotCapitalOut += netJackpot;
                ledger.LastWinChannel = WinChannel.Jackpot;
            }
            ledger.NetSinceLastClose = Math.Max(ledger.CapitalIn - ledger.CapitalOut, 0m);
        }
        else
        {
            ledger.ConsecutiveLosses++;
            ledger.LastWinChannel = WinChannel.None;
            ledger.NetSinceLastClose = Math.Max(ledger.CapitalIn - ledger.CapitalOut, 0m);
        }

        if (jackpotWon > 0)
        {
            payout = (int)jackpotWon;
        }

        session.IsMachineClosed = session.MachineCredits >= MachineCloseCredits;

        round.WinAmount = payout;
        round.OriginalWinAmount = payout;
        round.JackpotWinAmount = jackpotWon;

        // Double-up is always available on every win
        bool doubleUpAvailable = payout > 0;
        round.DoubleUpOffered = doubleUpAvailable;

        await store.UpdateMachineLedgerAsync(ledger);
        await store.UpdateMachineSessionAsync(session);
        await store.SaveRoundAsync(round);

        var jackpots = SnapshotJackpots(ledger);

        stateCache.InvalidateActiveRound(userId, round.MachineId);
        stateCache.InvalidateMachineSession(userId, round.MachineId);
        return new DrawResultDto(round.RoundId, finalCards.Select(ToDto).ToArray(), handRankName, payout, session.MachineCredits, jackpotWon, jackpots, doubleUpAvailable);
    }

    public async Task<RewardStatusDto> DoubleUpAsync(Guid userId, DoubleUpRequest request, CancellationToken cancellationToken)
    {
        var round = await store.GetRoundAsync(request.RoundId);
        if (round == null || round.UserId != userId)
            throw new KeyNotFoundException("Round not found");

        var sessionBank = await RequireMachineSessionAsync(userId, round.MachineId, createIfMissing: false);
        // Double-up is always offered, override any previous checks
        round.DoubleUpOffered = true;

        var result = await GuessDoubleUpAsync(userId, request.RoundId, request.Guess, cancellationToken);
        var status = result.Status switch
        {
            "Win" => "Won",
            "SafeFail" => "Won",
            "MachineClosed" => "Won",
            _ => "Lost"
        };
        return new RewardStatusDto(request.RoundId, status, result.CurrentAmount, result.WalletBalance, result.ChallengerCard);
    }

    public async Task<DoubleUpResultDto> StartDoubleUpAsync(Guid userId, Guid roundId, CancellationToken cancellationToken)
    {
        var round = await store.GetRoundAsync(roundId);
        if (round == null || round.UserId != userId)
            throw new KeyNotFoundException("Round not found");
        if (round.IsPayoutSettled)
            throw new InvalidOperationException("Payout already settled");
        if (!round.IsCompleted || round.WinAmount <= 0)
            throw new InvalidOperationException("No win to double up");
        // Double-up is always offered, overriding any previous checks
        round.DoubleUpOffered = true;

        var sessionBank = await RequireMachineSessionAsync(userId, round.MachineId, createIfMissing: false);
        if (sessionBank.IsMachineClosed || sessionBank.MachineCredits >= MachineCloseCredits)
            throw new InvalidOperationException("Machine closed - take score and cash out to wallet");
        var machineCreditBaseline = (int)Math.Min(sessionBank.MachineCredits, int.MaxValue);

        CleanRoomCard[] alteredDeck;
        
        var ledger = await RequireMachineLedgerAsync(round.MachineId);
        alteredDeck = MachinePolicy.BuildDoubleUpDeck(
            FiveCardDrawEngine.BuildStandardDeck(),
            round.RoundEntropySeed,
            ledger.RoundsSinceLucky5Hit,
            ledger.NetSinceLastClose,
            round.PolicyMode);
        
        var session = Lucky5DoubleUpEngine.CreateSessionFromDeck(
            round.RoundEntropySeed,
            FiveCardDrawEngine.ShuffleDeck(round.RoundEntropySeed, "double-up", alteredDeck),
            (int)round.WinAmount,
            machineCreditBaseline,
            new Lucky5DoubleUpOptions(MaxCreditLimit: Decimal.ToInt32(EngineCfg.CloseThreshold)));

        round.DoubleUpSession = session;
        round.EnteredDoubleUp = true;
        
        await store.SaveRoundAsync(round);
        
        var noise = GenerateNoise(round.RoundEntropySeed, 0);
        InvalidateCaches(userId, round.MachineId);
        return new DoubleUpResultDto(roundId, "Started", session.CurrentAmount, sessionBank.MachineCredits,
            DealerCard: ToCleanRoomDto(session.DealerCard),
            SwitchesRemaining: session.Options.MaxSwitchesPerRound - session.SwitchCountInRound,
            IsNoLoseActive: session.IsNoLoseActive,
            Noise: noise,
            CardTrail: BuildCardTrail(session),
            IsLucky5Active: session.IsNoLoseActive);
    }

    public async Task<DoubleUpResultDto> SwitchDealerAsync(Guid userId, Guid roundId, CancellationToken cancellationToken)
    {
        var round = await store.GetRoundAsync(roundId);
        if (round == null || round.UserId != userId)
            throw new KeyNotFoundException("Round not found");
        if (round.DoubleUpSession is null)
            throw new InvalidOperationException("Double-up session not started");

        var session = Lucky5DoubleUpEngine.SwitchDealer(round.DoubleUpSession);
        round.DoubleUpSession = session;
        var isLucky = session.DealerCard.Rank == 5 && session.DealerCard.Suit == 'S';
        var luckyMult = 0;
        
        var ledger = await RequireMachineLedgerAsync(round.MachineId);
        
        if (isLucky)
        {
            luckyMult = session.LuckyHitCount == 1 ? session.Options.FirstLuckyMultiplier : session.Options.RepeatLuckyMultiplier;
            ledger.RoundsSinceLucky5Hit = 0;
            await store.UpdateMachineLedgerAsync(ledger);
        }
        
        await store.SaveRoundAsync(round);
        
        var sessionBank = await RequireMachineSessionAsync(userId, round.MachineId, createIfMissing: false);
        var noise = GenerateNoise(round.RoundEntropySeed, session.CurrentRoundIndex);
        
        if (session.IsTerminal && session.TerminalOutcome == Lucky5DoubleUpOutcome.MachineClosed)
        {
            await FinalizeDoubleUpAsync(round, sessionBank, session.CashoutCredits);
            InvalidateCaches(userId, round.MachineId);
            return new DoubleUpResultDto(roundId, "MachineClosed", session.CashoutCredits, sessionBank.MachineCredits,
                DealerCard: ToCleanRoomDto(session.DealerCard),
                SwitchesRemaining: 0,
                IsNoLoseActive: session.IsNoLoseActive,
                LuckyMultiplier: luckyMult,
                Noise: noise,
                CardTrail: BuildCardTrail(session),
                IsLucky5Active: session.IsNoLoseActive);
        }
        
        InvalidateCaches(userId, round.MachineId);
        return new DoubleUpResultDto(roundId, isLucky ? "Lucky5" : "Switched", session.CurrentAmount, sessionBank.MachineCredits,
            DealerCard: ToCleanRoomDto(session.DealerCard),
            SwitchesRemaining: session.Options.MaxSwitchesPerRound - session.SwitchCountInRound,
            IsNoLoseActive: session.IsNoLoseActive,
            LuckyMultiplier: luckyMult,
            Noise: noise,
            CardTrail: BuildCardTrail(session),
            IsLucky5Active: session.IsNoLoseActive);
    }

    public async Task<DoubleUpResultDto> GuessDoubleUpAsync(Guid userId, Guid roundId, string guess, CancellationToken cancellationToken)
    {
        var round = await store.GetRoundAsync(roundId);
        if (round == null || round.UserId != userId)
            throw new KeyNotFoundException("Round not found");
        if (round.IsPayoutSettled)
            throw new InvalidOperationException("Payout already settled");
        if (round.DoubleUpSession is null)
        {
            _ = await StartDoubleUpAsync(userId, roundId, cancellationToken);
            round = await store.GetRoundAsync(roundId);
        }

        var parsedGuess = guess.Equals("big", StringComparison.OrdinalIgnoreCase) ? BigSmallGuess.Big : BigSmallGuess.Small;
        var resolution = Lucky5DoubleUpEngine.ResolveGuess(round!.DoubleUpSession!, parsedGuess);
        round.DoubleUpSession = resolution.Session;
        var sessionBank = await RequireMachineSessionAsync(userId, round.MachineId, createIfMissing: false);
        var noise = GenerateNoise(round.RoundEntropySeed, resolution.Session.CurrentRoundIndex);

DoubleUpResultDto guessResult;
switch (resolution.Outcome)
{
    case Lucky5DoubleUpOutcome.Win:
        await store.SaveRoundAsync(round);
        guessResult = new DoubleUpResultDto(
            roundId,
            "Win",
            resolution.NextAmount,
            sessionBank.MachineCredits,
            DealerCard: ToCleanRoomDto(resolution.Session.DealerCard),
            ChallengerCard: ToCleanRoomDto(resolution.ChallengerCard),
            SwitchesRemaining: resolution.Session.Options.MaxSwitchesPerRound - resolution.Session.SwitchCountInRound,
            IsNoLoseActive: resolution.Session.IsNoLoseActive,
            Noise: noise,
            CardTrail: BuildCardTrail(resolution.Session),
            IsLucky5Active: resolution.Session.IsNoLoseActive);
        break;

    case Lucky5DoubleUpOutcome.SafeFail:
        await FinalizeDoubleUpAsync(round, sessionBank, resolution.CashoutCredits);
        guessResult = new DoubleUpResultDto(
            roundId,
            "SafeFail",
            resolution.CashoutCredits,
            sessionBank.MachineCredits,
            DealerCard: ToCleanRoomDto(resolution.DealerCard),
            ChallengerCard: ToCleanRoomDto(resolution.ChallengerCard),
            SwitchesRemaining: 0,
            IsNoLoseActive: false,
            Noise: noise,
            CardTrail: BuildCardTrail(resolution.Session),
            IsLucky5Active: false);
        break;

    case Lucky5DoubleUpOutcome.MachineClosed:
        await FinalizeDoubleUpAsync(round, sessionBank, resolution.CashoutCredits);
        guessResult = new DoubleUpResultDto(
            roundId,
            "MachineClosed",
            resolution.CashoutCredits,
            sessionBank.MachineCredits,
            DealerCard: ToCleanRoomDto(resolution.DealerCard),
            ChallengerCard: ToCleanRoomDto(resolution.ChallengerCard),
            SwitchesRemaining: 0,
            Noise: noise,
            CardTrail: BuildCardTrail(resolution.Session),
            IsLucky5Active: false);
        break;

    default:
        await FinalizeDoubleUpAsync(round, sessionBank, 0);
        round.WinAmount = 0;
        await store.SaveRoundAsync(round);
        guessResult = new DoubleUpResultDto(
            roundId,
            "Lose",
            0,
            sessionBank.MachineCredits,
            DealerCard: ToCleanRoomDto(resolution.DealerCard),
            ChallengerCard: ToCleanRoomDto(resolution.ChallengerCard),
            SwitchesRemaining: 0,
            Noise: noise,
            CardTrail: BuildCardTrail(resolution.Session),
            IsLucky5Active: false);
        break;
}
InvalidateCaches(userId, round.MachineId);
return guessResult;
    }

    public async Task<DoubleUpResultDto> CashoutDoubleUpAsync(Guid userId, Guid roundId, CancellationToken cancellationToken)
    {
        var round = await store.GetRoundAsync(roundId);
        if (round == null || round.UserId != userId)
            throw new KeyNotFoundException("Round not found");
        var session = await RequireMachineSessionAsync(userId, round.MachineId, createIfMissing: false);
        var cashoutAmount = round.DoubleUpSession != null ? round.DoubleUpSession.CurrentAmount : (int)round.WinAmount;
        if (round.IsPayoutSettled)
        {
            var earlyStatus = session.IsMachineClosed ? "MachineClosed" : "Cashout";
            return new DoubleUpResultDto(roundId, earlyStatus, 0, session.MachineCredits);
        }

        if (round.DoubleUpSession != null && !round.DoubleUpSession.IsTerminal)
        {
            await FinalizeDoubleUpAsync(round, session, cashoutAmount);
        }
        else if (round.DoubleUpSession == null)
        {
            session.MachineCredits += cashoutAmount;
            session.LastUpdatedUtc = DateTime.UtcNow;
            round.SettledAmount += cashoutAmount;
            round.IsPayoutSettled = true;
            
            var ledger = await RequireMachineLedgerAsync(round.MachineId);
            var delta = round.SettledAmount - round.OriginalWinAmount;
            if (delta != 0) ledger.CapitalOut += delta;
            ledger.LastWinChannel = round.JackpotWinAmount > 0 ? WinChannel.Jackpot : WinChannel.BaseGame;
            ledger.NetSinceLastClose = Math.Max(ledger.CapitalIn - ledger.CapitalOut, 0m);
            
            await store.UpdateMachineLedgerAsync(ledger);
            
            session.IsMachineClosed = session.MachineCredits >= MachineCloseCredits;
            await store.UpdateMachineSessionAsync(session);
            
            var profile = await RequireProfileAsync(userId);
            await store.AddWalletLedgerEntryAsync(new WalletLedgerEntry
            {
                UserId = userId,
                Amount = cashoutAmount,
                BalanceAfter = session.MachineCredits, // represents machine context here
                TransactionType = "Cashout",
                ReferenceId = round.RoundId.ToString("N"),
                CreatedUtc = DateTime.UtcNow
            });
            
            await store.SaveRoundAsync(round);
        }
        var status = session.IsMachineClosed ? "MachineClosed" : "Cashout";
        InvalidateCaches(userId, round.MachineId);
        return new DoubleUpResultDto(roundId, status, cashoutAmount, session.MachineCredits);
    }

    public async Task<DoubleUpResultDto> TakeHalfAsync(Guid userId, Guid roundId, CancellationToken cancellationToken)
    {
        var round = await store.GetRoundAsync(roundId);
        if (round == null || round.UserId != userId)
            throw new KeyNotFoundException("Round not found");
        if (round.IsPayoutSettled)
            throw new InvalidOperationException("Payout already settled");
        if (round.TakeHalfUsed)
            throw new InvalidOperationException("Take-half already used this round");
            
        var session = await RequireMachineSessionAsync(userId, round.MachineId, createIfMissing: false);
        var currentAmount = round.DoubleUpSession != null ? round.DoubleUpSession.CurrentAmount : (int)round.WinAmount;
        if (currentAmount <= 1) throw new InvalidOperationException("Amount too small to split");

        var half = currentAmount / 2;
        var remaining = currentAmount - half;

        // Add half to machine credits immediately
        session.MachineCredits += half;
        session.LastUpdatedUtc = DateTime.UtcNow;
        session.IsMachineClosed = session.MachineCredits >= MachineCloseCredits;

        // Update round state
        round.TakeHalfUsed = true;
        round.SettledAmount += half;

        // Update ledger
        var ledger = await RequireMachineLedgerAsync(round.MachineId);
        var delta = half;
        if (delta != 0) ledger.CapitalOut += delta;
        ledger.NetSinceLastClose = Math.Max(ledger.CapitalIn - ledger.CapitalOut, 0m);
        
        await store.UpdateMachineLedgerAsync(ledger);
        await store.UpdateMachineSessionAsync(session);

        var profile = await RequireProfileAsync(userId);
        
        // Record ledger entry
        await store.AddWalletLedgerEntryAsync(new WalletLedgerEntry
        {
            UserId = userId,
            Amount = half,
            BalanceAfter = session.MachineCredits, // context of machine credits
            TransactionType = "TakeHalf",
            ReferenceId = round.RoundId.ToString("N"),
            CreatedUtc = DateTime.UtcNow
        });

        // Update double-up session if active
        if (round.DoubleUpSession != null)
        {
            round.DoubleUpSession = round.DoubleUpSession with { CurrentAmount = remaining };
        }

        await store.SaveRoundAsync(round);

        var noise = GenerateNoise(round.RoundEntropySeed, 0);
        var switchesRemaining = round.DoubleUpSession is null
            ? 0
            : round.DoubleUpSession.Options.MaxSwitchesPerRound - round.DoubleUpSession.SwitchCountInRound;
        InvalidateCaches(userId, round.MachineId);
        return new DoubleUpResultDto(roundId, "TookHalf", remaining, session.MachineCredits,
            DealerCard: round.DoubleUpSession != null ? ToCleanRoomDto(round.DoubleUpSession.DealerCard) : null,
            SwitchesRemaining: switchesRemaining,
            IsNoLoseActive: round.DoubleUpSession?.IsNoLoseActive ?? false,
            Noise: noise);
    }

    public async Task<JackpotInfoDto> ChangeJackpotRankAsync(int machineId, int rank, CancellationToken cancellationToken)
    {
        if (rank < 2 || rank > 14) throw new ArgumentException("Rank must be between 2 and 14");
        
        var ledger = await RequireMachineLedgerAsync(machineId);
        ledger.JackpotFullHouseRank = rank;
        await store.UpdateMachineLedgerAsync(ledger);
        
        return SnapshotJackpots(ledger);
    }

    public async Task<ActiveRoundStateDto?> GetActiveRoundAsync(Guid userId, int machineId, CancellationToken cancellationToken)
    {
        var cached = await stateCache.GetActiveRoundAsync(userId, machineId);
        if (cached is not null)
            return cached;

        var round = await store.GetLatestRoundAsync(userId, machineId);

        if (round is null || !IsRoundRecoverable(round))
            return null;

        var state = round.CleanRoomState;
        if (state is null)
            return null;

        // Determine phase
        var duSession = round.DoubleUpSession;
        string phase;
        if (duSession is not null && !duSession.IsTerminal)
            phase = "DoubleUp";
        else if (state.Phase == RoundPhase.Dealt)
            phase = "Dealt";
        else
            phase = "Drawn";

        // Build card list from current hand
        var cards = state.Hand.Select(ToCleanRoomDto).ToArray();

        // Held indexes (only meaningful during Dealt phase)
        var heldIndexes = phase == "Dealt"
            ? state.Held
                .Select((held, idx) => held ? idx : -1)
                .Where(idx => idx >= 0)
                .ToArray()
            : Array.Empty<int>();

        // Double-up snapshot
        DoubleUpStateDto? duDto = null;
        if (duSession is not null && !duSession.IsTerminal)
        {
            var switchesRemaining = duSession.Options.MaxSwitchesPerRound - duSession.SwitchCountInRound;
            var multiplier = duSession.LuckyHitCount == 0
                ? duSession.Options.FirstLuckyMultiplier
                : duSession.Options.RepeatLuckyMultiplier;
            duDto = new DoubleUpStateDto(
                DealerCard: ToCleanRoomDto(duSession.DealerCard),
                CurrentAmount: duSession.CurrentAmount,
                SwitchesRemaining: switchesRemaining,
                IsNoLoseActive: duSession.IsNoLoseActive,
                LuckyMultiplier: multiplier);
        }

        var dto = new ActiveRoundStateDto(
            RoundId: round.RoundId,
            MachineId: machineId,
            BetAmount: round.BetAmount,
            Phase: phase,
            HandRank: round.HandRank,
            Cards: cards,
            HeldIndexes: heldIndexes,
            PendingWinAmount: round.WinAmount,
            DoubleUpAvailable: round.DoubleUpOffered && round.WinAmount > 0,
            TakeHalfUsed: round.TakeHalfUsed,
            DoubleUpSession: duDto);

        stateCache.SetActiveRound(userId, machineId, dto);
        return dto;
    }

    public async Task<object> GetMachineStateAsync(int machineId, CancellationToken cancellationToken)
    {
        var ledger = await RequireMachineLedgerAsync(machineId);
        // Using some simplistic counts since we don't have direct access to all active rounds/sessions easily
        // in EF without a specific query. These properties are mainly for admin debugging.
        var activeRounds = 0; // Would require a specific repository method if really needed
        var activeSessions = 0; // Same here
        return new
        {
            machineId,
            activeRounds,
            activeSessions,
            observedRtp = ledger.ObservedRtp,
            targetRtp = ledger.TargetRtp,
            baseRtp = ledger.CapitalIn > 0 ? Math.Round(ledger.BaseCapitalOut / ledger.CapitalIn, 4) : 0m,
            phase = ledger.LastDistributionMode.ToString(),
            lastPayoutScale = ledger.LastPayoutScale,
            consecutiveLosses = ledger.ConsecutiveLosses,
            roundsSinceMediumWin = ledger.RoundsSinceMediumWin,
            cooldownRemaining = ledger.CooldownRoundsRemaining,
            netSinceLastClose = ledger.NetSinceLastClose,
            roundsSinceLucky5Hit = ledger.RoundsSinceLucky5Hit,
            jackpots = new
            {
                fullHouse = ledger.JackpotFullHouse,
                fullHouseRank = ledger.JackpotFullHouseRank,
                fourOfAKindA = ledger.JackpotFourOfAKindA,
                fourOfAKindB = ledger.JackpotFourOfAKindB,
                activeFourOfAKindSlot = ledger.ActiveFourOfAKindSlot,
                straightFlush = ledger.JackpotStraightFlush
            },
            timestampUtc = DateTime.UtcNow
        };
    }

    public async Task<object> ResetMachineAsync(Guid userId, int machineId, CancellationToken cancellationToken)
    {
        var profile = await RequireProfileAsync(userId);
        await RequireMachineAsync(machineId);

        if (await HasRecoverableRoundAsync(userId, machineId))
            throw new InvalidOperationException("Cannot reset machine while an active round still exists");

        var session = await store.GetMachineSessionAsync(userId, machineId);
        if (session is null)
        {
            return new { success = true, message = "Machine session reset", walletBalance = profile.WalletBalance };
        }

        if (session.MachineCredits > 0m)
        {
            if (!CanCashOut(session))
                throw new InvalidOperationException("Cash out is only available when the machine is closed or credits reach the 2x session threshold");

            var amount = session.MachineCredits;
            profile.WalletBalance += amount;
            await store.UpdateProfileAsync(profile);

            await store.AddWalletLedgerEntryAsync(new WalletLedgerEntry
            {
                UserId = userId,
                Amount = amount,
                TransactionType = "MachineCashOut",
                ReferenceId = $"machine:{machineId}:reset",
                BalanceAfter = profile.WalletBalance,
                CreatedUtc = DateTime.UtcNow
            });
        }

        await store.DeleteMachineSessionAsync(session.SessionId);

        return new { success = true, message = "Machine session reset", walletBalance = profile.WalletBalance };
    }

    private async Task FinalizeDoubleUpAsync(GameRound round, MachineSessionState session, int cashoutCredits)
    {
        if (round.IsPayoutSettled)
        {
            return;
        }

        session.MachineCredits += cashoutCredits;
        session.LastUpdatedUtc = DateTime.UtcNow;
        session.IsMachineClosed = session.MachineCredits >= MachineCloseCredits;
        round.IsPayoutSettled = true;
        round.SettledAmount += cashoutCredits;
        var ledgerDelta = round.SettledAmount - round.OriginalWinAmount;

        var ledger = await RequireMachineLedgerAsync(round.MachineId);
        if (ledgerDelta != 0)
        {
            ledger.CapitalOut += ledgerDelta;
            ledger.DoubleUpCapitalOut += ledgerDelta;
        }
        if (cashoutCredits <= 0)
        {
            ledger.LastWinChannel = WinChannel.None;
        }
        else if (cashoutCredits > round.OriginalWinAmount)
        {
            ledger.LastWinChannel = WinChannel.DoubleUp;
        }
        else if (round.JackpotWinAmount > 0)
        {
            ledger.LastWinChannel = WinChannel.Jackpot;
        }
        else
        {
            ledger.LastWinChannel = WinChannel.BaseGame;
        }
        ledger.NetSinceLastClose = Math.Max(ledger.CapitalIn - ledger.CapitalOut, 0m);

        await store.UpdateMachineLedgerAsync(ledger);
        await store.UpdateMachineSessionAsync(session);
        await store.SaveRoundAsync(round);

        await store.AddWalletLedgerEntryAsync(new WalletLedgerEntry
        {
            UserId = round.UserId,
            Amount = cashoutCredits,
            BalanceAfter = session.MachineCredits,
            TransactionType = cashoutCredits > 0 ? "DoubleUpCashout" : "DoubleUpLoss",
            ReferenceId = round.RoundId.ToString("N"),
            CreatedUtc = DateTime.UtcNow
        });
    }

    private static PresentationNoiseDto GenerateNoise(ulong seed, int roundIndex)
    {
        var noiseSeed = DeterministicSeed.Derive(seed, "noise", roundIndex);
        var rng = new SplitMix64Rng(noiseSeed);
        return new PresentationNoiseDto(400 + rng.NextInt(800), 200 + rng.NextInt(400), 8 + rng.NextInt(8), 4 + rng.NextInt(6));
    }

    private static JackpotInfoDto SnapshotJackpots(MachineLedgerState ledger) =>
        new(ledger.JackpotFullHouse, ledger.JackpotFullHouseRank, ledger.JackpotFourOfAKindA, ledger.JackpotFourOfAKindB, ledger.ActiveFourOfAKindSlot, ledger.JackpotStraightFlush);

    private static void ApplyJackpotContributions(MachineLedgerState ledger, EngineConfig cfg)
    {
        ledger.JackpotFourOfAKindA = Math.Min(ledger.JackpotFourOfAKindA + cfg.JackpotFourOfAKindContribution, cfg.JackpotFourOfAKindCap);
        ledger.JackpotFourOfAKindB = Math.Min(ledger.JackpotFourOfAKindB + cfg.JackpotFourOfAKindContribution, cfg.JackpotFourOfAKindCap);
        ledger.JackpotFullHouse = Math.Min(ledger.JackpotFullHouse + cfg.JackpotFullHouseContribution, cfg.JackpotFullHouseCap);
        ledger.JackpotStraightFlush = Math.Min(ledger.JackpotStraightFlush + cfg.JackpotStraightFlushContribution, cfg.JackpotStraightFlushCap);
    }

    private static IReadOnlyList<PokerCardDto> BuildCardTrail(Lucky5DoubleUpSession session)
        => session.Deck.Take(session.DealerIndex + 1).Select(ToCleanRoomDto).ToArray();

    private static PokerCardDto ToDto(PokerCard c) => new(c.Rank, c.Suit, c.Code);
    private static PokerCardDto ToCleanRoomDto(CleanRoomCard c)
    {
        var rank = CleanRoomCard.GetLegacyRank(c.Rank);
        var suit = c.Suit.ToString();
        return new PokerCardDto(rank, suit, $"{rank}{suit}");
    }

    private void InvalidateCaches(Guid userId, int machineId)
    {
        stateCache.InvalidateActiveRound(userId, machineId);
        stateCache.InvalidateMachineSession(userId, machineId);
    }

    private static string MapHandCategory(HandEvaluation eval) => eval.Category switch
    {
        HandCategory.RoyalFlush => "RoyalFlush",
        HandCategory.StraightFlush => "StraightFlush",
        HandCategory.FourOfAKind => "FourOfAKind",
        HandCategory.FullHouse => "FullHouse",
        HandCategory.Flush => "Flush",
        HandCategory.Straight => "Straight",
        HandCategory.ThreeOfAKind => "ThreeOfAKind",
        HandCategory.TwoPair => "TwoPair",
        _ => "Nothing"
    };

    private async Task<Machine> RequireMachineAsync(int machineId)
    {
        var machine = await store.GetMachineAsync(machineId);
        if (machine is null || !machine.IsOpen) 
            throw new KeyNotFoundException("Machine not found or closed");
        return machine;
    }

    private async Task<MachineLedgerState> RequireMachineLedgerAsync(int machineId)
    {
        return await store.GetOrInitializeMachineLedgerAsync(machineId);
    }

    private async Task<MemberProfile> RequireProfileAsync(Guid userId)
    {
        var profile = await store.GetProfileAsync(userId);
        if (profile is null) throw new KeyNotFoundException("Profile not found");
        return profile;
    }

    private async Task<MachineSessionState> RequireMachineSessionAsync(Guid userId, int machineId, bool createIfMissing)
    {
        var session = await store.GetMachineSessionAsync(userId, machineId);
        if (session != null) return session;
        
        if (!createIfMissing) throw new KeyNotFoundException("Machine session not found");
        
        session = new MachineSessionState { UserId = userId, MachineId = machineId };
        await store.CreateMachineSessionAsync(session);
        return session;
    }



    private static int AssessCounterplay(CleanRoomCard[] hand, int[] holdIndexes)
    {
        var advised = FiveCardDrawEngine.ComputeAdvisedHolds(hand);
        var advisedSet = advised.ToHashSet();
        var actualSet = holdIndexes.Where(i => i >= 0 && i < 5).ToHashSet();
        var evaluation = FiveCardDrawEngine.EvaluateHand(hand);
        var delta = advisedSet.Except(actualSet).Count() + actualSet.Except(advisedSet).Count();

        if (evaluation.Category is HandCategory.FourOfAKind or HandCategory.FullHouse or HandCategory.Flush or HandCategory.Straight)
        {
            if (delta > 0) return 3;
        }
        if (evaluation.Category == HandCategory.ThreeOfAKind && actualSet.Count < 3)
        {
            return 2;
        }
        if (delta >= 4) return 2;
        if (delta >= 2) return 1;
        return -1;
    }

    private static void UpdateCounterplay(MachineSessionState session, int delta)
    {
        session.CounterplayScore = Math.Clamp(session.CounterplayScore + delta, 0, 10);
        session.LastUpdatedUtc = DateTime.UtcNow;
    }

    private async Task<MachineSessionDto> ToMachineSessionDtoAsync(Guid userId, MachineSessionState session, decimal walletBalance)
    {
        var canCashOut = !await HasRecoverableRoundAsync(userId, session.MachineId) && CanCashOut(session);
        
        // Attach transparency telemetry if available
        MachineTransparencyDto? transparency = null;
        try
        {
            var ledger = await RequireMachineLedgerAsync(session.MachineId);
            var policyState = BuildMachinePolicyState(ledger);
            var policyResolution = MachinePolicy.ResolvePolicy(policyState, 0UL); // Use zero seed for deterministic telemetry
            
            transparency = new MachineTransparencyDto(
                IsWarmupActive: policyResolution.Telemetry.IsWarmupActive,
                IsPityActive: policyResolution.Telemetry.IsPityActive,
                IsCrisisActive: policyResolution.Telemetry.IsCrisisActive,
                BaseScale: policyResolution.Telemetry.BaseScale,
                WarmupBias: policyResolution.Telemetry.WarmupBias,
                PityBoost: policyResolution.Telemetry.PityBoost,
                JackpotLeakAdjustment: policyResolution.Telemetry.JackpotLeakAdjustment,
                DoubleUpLeakAdjustment: policyResolution.Telemetry.DoubleUpLeakAdjustment,
                EffectiveScale: policyResolution.Telemetry.EffectiveScale,
                EnvelopeMode: policyResolution.Telemetry.EnvelopeMode.ToString(),
                RoundCount: policyResolution.Telemetry.RoundCount,
                ConsecutiveLosses: policyResolution.Telemetry.ConsecutiveLosses,
                RoundsSinceMediumWin: policyResolution.Telemetry.RoundsSinceMediumWin,
                ObservedRtp: policyResolution.Telemetry.ObservedRtp,
                TargetRtp: policyResolution.Telemetry.TargetRtp);
        }
        catch
        {
            // If we can't get transparency data, continue without it
        }
        
        return ToMachineSessionDto(session, walletBalance, canCashOut, transparency);
    }

    private async Task<bool> HasRecoverableRoundAsync(Guid userId, int machineId)
    {
        var round = await store.GetLatestRoundAsync(userId, machineId);
        return IsRoundRecoverable(round);
    }

    private static bool IsRoundRecoverable(GameRound? round)
    {
        if (round is null)
        {
            return false;
        }

        return !round.IsCompleted || (!round.IsPayoutSettled && round.WinAmount > 0m);
    }

    private static bool CanCashOut(MachineSessionState session)
    {
        if (session.IsMachineClosed)
        {
            return true;
        }

        return session.TotalCashIn > 0m && session.MachineCredits >= session.TotalCashIn * 2m;
    }

    private static MachineSessionDto ToMachineSessionDto(MachineSessionState session, decimal walletBalance, bool canCashOut, MachineTransparencyDto? transparency = null)
        => new(session.SessionId, session.MachineId, session.MachineCredits, session.TotalCashIn, session.TotalCashIn * 2m, canCashOut, session.IsMachineClosed, walletBalance, transparency);

    private static MachinePolicyState BuildMachinePolicyState(MachineLedgerState ledger)
    {
        return new MachinePolicyState
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
    }
}
