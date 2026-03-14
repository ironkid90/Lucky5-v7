namespace Lucky5.Infrastructure.Services;

using Lucky5.Application.Contracts;
using Lucky5.Application.Dtos;
using Lucky5.Application.Requests;
using Lucky5.Domain.Entities;
using Lucky5.Domain.Game.CleanRoom;

public sealed class GameService(InMemoryDataStore store, IEntropyGenerator entropyGenerator) : IGameService
{
    private const decimal CashInUnit = 200_000m;
    private const decimal MaxSessionCashIn = 1_000_000m;
    private const decimal MachineCloseCredits = 50_000_000m;

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

    public Task<IReadOnlyList<MachineListingDto>> GetMachinesAsync(CancellationToken cancellationToken)
        => Task.FromResult<IReadOnlyList<MachineListingDto>>(store.Machines.Select(x => new MachineListingDto(x.Id, x.Name, x.IsOpen, x.MinBet, x.MaxBet)).ToArray());

    public Task<DefaultRulesDto> GetDefaultRulesAsync(CancellationToken cancellationToken)
        => Task.FromResult(new DefaultRulesDto(new Dictionary<string, decimal>(Rules)));

    public Task<IReadOnlyList<OfferDto>> GetOffersAsync(CancellationToken cancellationToken)
        => Task.FromResult<IReadOnlyList<OfferDto>>(store.Offers.Select(x => new OfferDto(x.Id, x.Title, x.Description, x.BonusAmount)).ToArray());

    public Task<MachineSessionDto> GetMachineSessionAsync(Guid userId, int machineId, CancellationToken cancellationToken)
    {
        var profile = RequireProfile(userId);
        RequireMachine(machineId);
        var session = RequireMachineSession(userId, machineId, createIfMissing: true);
        return Task.FromResult(ToMachineSessionDto(session, profile.WalletBalance));
    }

    public Task<MachineSessionDto> CashInAsync(Guid userId, int machineId, decimal amount, CancellationToken cancellationToken)
    {
        var profile = RequireProfile(userId);
        RequireMachine(machineId);
        var session = RequireMachineSession(userId, machineId, createIfMissing: true);

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

        store.Ledger.Add(new WalletLedgerEntry
        {
            UserId = userId,
            Amount = -amount,
            Type = "MachineCashIn",
            Reference = $"machine:{machineId}:cashin",
            BalanceAfter = profile.WalletBalance,
            CreatedUtc = DateTime.UtcNow
        });

        return Task.FromResult(ToMachineSessionDto(session, profile.WalletBalance));
    }

    public Task<MachineSessionDto> CashOutAsync(Guid userId, int machineId, CancellationToken cancellationToken)
    {
        var profile = RequireProfile(userId);
        var session = RequireMachineSession(userId, machineId, createIfMissing: false);
        if (session.MachineCredits <= 0)
            throw new InvalidOperationException("No machine credits to cash out");
        if (!CanCashOut(session))
            throw new InvalidOperationException("Cash out requires machine closed or at least 2x your total cash-in");

        var amount = session.MachineCredits;
        profile.WalletBalance += amount;
        session.MachineCredits = 0;
        session.TotalCashIn = 0;
        session.IsMachineClosed = false;
        session.LastUpdatedUtc = DateTime.UtcNow;

        store.Ledger.Add(new WalletLedgerEntry
        {
            UserId = userId,
            Amount = amount,
            Type = "MachineCashOut",
            Reference = $"machine:{machineId}:cashout",
            BalanceAfter = profile.WalletBalance,
            CreatedUtc = DateTime.UtcNow
        });

        return Task.FromResult(ToMachineSessionDto(session, profile.WalletBalance));
    }

    public Task<DealResultDto> DealAsync(Guid userId, DealRequest request, CancellationToken cancellationToken)
    {
        var machine = RequireMachine(request.MachineId);
        var session = RequireMachineSession(userId, request.MachineId, createIfMissing: true);
        if (session.IsMachineClosed)
            throw new InvalidOperationException("Machine is closed - cash out to wallet before continuing");
        if (request.BetAmount <= 0 || request.BetAmount < machine.MinBet || request.BetAmount > machine.MaxBet)
            throw new InvalidOperationException("Bet amount is outside machine limits");
        if (session.MachineCredits < request.BetAmount * 2m)
            throw new InvalidOperationException("Insufficient machine credits for deal and draw - cash in from wallet first");

        ulong seed;
        PolicyDistributionMode policyMode;
        MachinePolicyState policyState;
        lock (store.LedgerSync)
        {
            var ledger = RequireMachineLedger(machine.Id);
            seed = entropyGenerator.CreateSeed(userId, machine.Id, request.BetAmount, ledger);
            policyState = new MachinePolicyState
            {
                CreditsIn = ledger.CapitalIn,
                CreditsOut = ledger.CapitalOut,
                BaseCreditsOut = ledger.BaseCapitalOut,
                TargetRtp = ledger.TargetRtp,
                RoundCount = ledger.RoundCount,
                ConsecutiveLosses = ledger.ConsecutiveLosses,
                RoundsSinceMediumWin = ledger.RoundsSinceMediumWin,
                CooldownRoundsRemaining = ledger.CooldownRoundsRemaining,
                NetSinceLastClose = ledger.NetSinceLastClose,
                RoundsSinceLucky5Hit = ledger.RoundsSinceLucky5Hit
            };
            policyMode = MachinePolicy.ResolveDistributionMode(policyState, seed);
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
            ledger.ActiveFourOfAKindSlot = (ledger.RoundCount % 2 == 0) ? (int)(seed % 2) : 1 - (int)(seed % 2);
            var cfg = EngineConfig.Default;
            ledger.JackpotFourOfAKindA = Math.Min(ledger.JackpotFourOfAKindA + 150, cfg.JackpotFourOfAKindCap);
            ledger.JackpotFourOfAKindB = Math.Min(ledger.JackpotFourOfAKindB + 150, cfg.JackpotFourOfAKindCap);
            ledger.JackpotFullHouse = Math.Min(ledger.JackpotFullHouse + 100, cfg.JackpotFullHouseCap);
            ledger.JackpotStraightFlush = Math.Min(ledger.JackpotStraightFlush + 150, cfg.JackpotStraightFlushCap);
            ledger.NetSinceLastClose = Math.Max(ledger.CapitalIn - ledger.CapitalOut, 0m);
        }

        var standardDeck = FiveCardDrawEngine.BuildStandardDeck();
        var alteredDeck = MachinePolicy.AlterDeck(standardDeck, policyMode, seed, policyState.ConsecutiveLosses);
        var shuffledDeck = FiveCardDrawEngine.ShuffleDeck(seed, "hand", alteredDeck);
        var hand = shuffledDeck.Take(5).ToArray();
        var drawState = FiveCardDrawState.Create(seed, shuffledDeck, hand);

        session.MachineCredits -= request.BetAmount;
        session.LastUpdatedUtc = DateTime.UtcNow;

        var cards = hand.Select(c => c.ToLegacyPokerCard()).ToList();
        int active4kSlot;
        lock (store.LedgerSync)
        {
            active4kSlot = RequireMachineLedger(request.MachineId).ActiveFourOfAKindSlot;
        }

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

        store.ActiveRounds[round.RoundId] = round;
        store.Ledger.Add(new WalletLedgerEntry
        {
            UserId = userId,
            Amount = -request.BetAmount,
            BalanceAfter = session.MachineCredits,
            Type = "Bet",
            Reference = round.RoundId.ToString("N"),
            CreatedUtc = DateTime.UtcNow
        });

        JackpotInfoDto jackpots;
        lock (store.LedgerSync)
        {
            jackpots = SnapshotJackpots(RequireMachineLedger(machine.Id));
        }

        var advisedHolds = FiveCardDrawEngine.ComputeAdvisedHolds(hand);
        return Task.FromResult(new DealResultDto(round.RoundId, cards.Select(ToDto).ToArray(), request.BetAmount, session.MachineCredits, jackpots, advisedHolds));
    }

    public Task<DrawResultDto> DrawAsync(Guid userId, DrawRequest request, CancellationToken cancellationToken)
    {
        if (!store.ActiveRounds.TryGetValue(request.RoundId, out var round) || round.UserId != userId)
            throw new KeyNotFoundException("Round not found");
        if (round.IsCompleted)
            throw new InvalidOperationException("Round already completed");
        if (round.CleanRoomState is null)
            throw new InvalidOperationException("Clean-room state not initialized");
        if (round.CleanRoomState.Phase != RoundPhase.Dealt)
            throw new InvalidOperationException("Draw already completed for this round");

        var session = RequireMachineSession(userId, round.MachineId, createIfMissing: false);
        if (session.IsMachineClosed)
            throw new InvalidOperationException("Machine is closed - cash out to wallet before continuing");
        if (session.MachineCredits < round.BetAmount)
            throw new InvalidOperationException("Not enough machine credits for draw");

        session.MachineCredits -= round.BetAmount;
        session.LastUpdatedUtc = DateTime.UtcNow;

        lock (store.LedgerSync)
        {
            var ledger = RequireMachineLedger(round.MachineId);
            ledger.CapitalIn += round.BetAmount;
            var cfg = EngineConfig.Default;
            ledger.JackpotFourOfAKindA = Math.Min(ledger.JackpotFourOfAKindA + 150, cfg.JackpotFourOfAKindCap);
            ledger.JackpotFourOfAKindB = Math.Min(ledger.JackpotFourOfAKindB + 150, cfg.JackpotFourOfAKindCap);
            ledger.JackpotFullHouse = Math.Min(ledger.JackpotFullHouse + 100, cfg.JackpotFullHouseCap);
            ledger.JackpotStraightFlush = Math.Min(ledger.JackpotStraightFlush + 150, cfg.JackpotStraightFlushCap);
            ledger.NetSinceLastClose = Math.Max(ledger.CapitalIn - ledger.CapitalOut, 0m);
        }

        store.Ledger.Add(new WalletLedgerEntry
        {
            UserId = userId,
            Amount = -round.BetAmount,
            BalanceAfter = session.MachineCredits,
            Type = "DrawBet",
            Reference = round.RoundId.ToString("N"),
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
        lock (store.LedgerSync)
        {
            var ledger = RequireMachineLedger(round.MachineId);
            var scaleState = new MachinePolicyState
            {
                CreditsIn = ledger.CapitalIn,
                CreditsOut = ledger.CapitalOut,
                BaseCreditsOut = ledger.BaseCapitalOut,
                TargetRtp = ledger.TargetRtp,
                RoundCount = ledger.RoundCount,
                ConsecutiveLosses = ledger.ConsecutiveLosses,
                RoundsSinceMediumWin = ledger.RoundsSinceMediumWin,
                CooldownRoundsRemaining = ledger.CooldownRoundsRemaining,
                NetSinceLastClose = ledger.NetSinceLastClose,
                RoundsSinceLucky5Hit = ledger.RoundsSinceLucky5Hit
            };
            var scaleResult = MachinePolicy.ResolvePayoutScale(scaleState, round.RoundEntropySeed);
            payoutScale = scaleResult.ForTier(MachinePolicy.ClassifyHand(evaluation.Category));
            if (session.CounterplayScore >= 6)
            {
                payoutScale = Math.Min(4.0m, payoutScale + 0.10m);
            }
            else if (session.CounterplayScore >= 3)
            {
                payoutScale = Math.Min(4.0m, payoutScale + 0.04m);
            }
            ledger.LastPayoutScale = payoutScale;
        }

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
            lock (store.LedgerSync)
            {
                var ledger = RequireMachineLedger(round.MachineId);
                ledger.CapitalOut += payout;
                ledger.BaseCapitalOut += basePayout;
                ledger.ConsecutiveLosses = 0;
                ledger.LastWinChannel = WinChannel.BaseGame;
                if (MachinePolicy.ClassifyHand(evaluation.Category) >= PayoutTier.Medium)
                    ledger.RoundsSinceMediumWin = 0;
                ledger.CooldownRoundsRemaining = MachinePolicy.ComputeCooldownLength(evaluation.Category, round.RoundEntropySeed);

                var jpCfg = EngineConfig.Default;
                if (evaluation.Category == HandCategory.FullHouse && evaluation.Tiebreak[0] == ledger.JackpotFullHouseRank)
                {
                    jackpotWon = ledger.JackpotFullHouse;
                    ledger.JackpotFullHouse = jpCfg.JackpotFullHouseStart;
                }
                else if (evaluation.Category == HandCategory.FourOfAKind)
                {
                    if (round.ActiveFourOfAKindSlotAtDeal == 0)
                    {
                        jackpotWon = ledger.JackpotFourOfAKindA;
                        ledger.JackpotFourOfAKindA = jpCfg.JackpotFourOfAKindStart;
                    }
                    else
                    {
                        jackpotWon = ledger.JackpotFourOfAKindB;
                        ledger.JackpotFourOfAKindB = jpCfg.JackpotFourOfAKindStart;
                    }
                }
                else if (evaluation.Category == HandCategory.StraightFlush)
                {
                    jackpotWon = ledger.JackpotStraightFlush;
                    ledger.JackpotStraightFlush = jpCfg.JackpotStraightFlushStart;
                }

                // Replace mode: jackpot replaces base payout if larger (not additive)
                if (jackpotWon > 0)
                {
                    var netJackpot = Math.Max(0m, jackpotWon - payout);
                    ledger.CapitalOut += netJackpot;
                    ledger.LastWinChannel = WinChannel.Jackpot;
                }
                ledger.NetSinceLastClose = Math.Max(ledger.CapitalIn - ledger.CapitalOut, 0m);
            }
        }
        else
        {
            lock (store.LedgerSync)
            {
                var ledger = RequireMachineLedger(round.MachineId);
                ledger.ConsecutiveLosses++;
                ledger.LastWinChannel = WinChannel.None;
                ledger.NetSinceLastClose = Math.Max(ledger.CapitalIn - ledger.CapitalOut, 0m);
            }
        }

        // Replace mode: jackpot replaces base payout if larger
        if (jackpotWon > 0 && jackpotWon > payout)
        {
            payout = (int)jackpotWon;
        }

        session.IsMachineClosed = session.MachineCredits >= MachineCloseCredits;

        round.WinAmount = payout;
        round.OriginalWinAmount = payout;
        round.JackpotWinAmount = jackpotWon;

        // Quantum offer gate: decide if double-up is available this round
        bool doubleUpAvailable = payout > 0;
        if (doubleUpAvailable)
        {
            lock (store.LedgerSync)
            {
                var ledger = RequireMachineLedger(round.MachineId);
                var offerState = new MachinePolicyState
                {
                    CreditsIn = ledger.CapitalIn,
                    CreditsOut = ledger.CapitalOut,
                    BaseCreditsOut = ledger.BaseCapitalOut,
                    TargetRtp = ledger.TargetRtp,
                    RoundCount = ledger.RoundCount,
                    ConsecutiveLosses = ledger.ConsecutiveLosses,
                    RoundsSinceMediumWin = ledger.RoundsSinceMediumWin,
                    CooldownRoundsRemaining = ledger.CooldownRoundsRemaining,
                    NetSinceLastClose = ledger.NetSinceLastClose,
                    RoundsSinceLucky5Hit = ledger.RoundsSinceLucky5Hit
                };
                doubleUpAvailable = MachinePolicy.ShouldOfferDoubleUp(offerState, round.RoundEntropySeed);
            }
        }
        round.DoubleUpOffered = doubleUpAvailable;

        JackpotInfoDto jackpots;
        lock (store.LedgerSync)
        {
            jackpots = SnapshotJackpots(RequireMachineLedger(round.MachineId));
        }

        return Task.FromResult(new DrawResultDto(round.RoundId, finalCards.Select(ToDto).ToArray(), handRankName, payout, session.MachineCredits, jackpotWon, jackpots, doubleUpAvailable));
    }

    public async Task<RewardStatusDto> DoubleUpAsync(Guid userId, DoubleUpRequest request, CancellationToken cancellationToken)
    {
        if (!store.ActiveRounds.TryGetValue(request.RoundId, out var round) || round.UserId != userId)
            throw new KeyNotFoundException("Round not found");

        var sessionBank = RequireMachineSession(userId, round.MachineId, createIfMissing: false);
        if (round.DoubleUpSession is null && !round.DoubleUpOffered)
        {
            return new RewardStatusDto(request.RoundId, "Unavailable", round.WinAmount, sessionBank.MachineCredits);
        }

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

    public Task<DoubleUpResultDto> StartDoubleUpAsync(Guid userId, Guid roundId, CancellationToken cancellationToken)
    {
        if (!store.ActiveRounds.TryGetValue(roundId, out var round) || round.UserId != userId)
            throw new KeyNotFoundException("Round not found");
        if (round.IsPayoutSettled)
            throw new InvalidOperationException("Payout already settled");
        if (!round.IsCompleted || round.WinAmount <= 0)
            throw new InvalidOperationException("No win to double up");
        if (!round.DoubleUpOffered)
            throw new InvalidOperationException("Double-up not available this round");

        var sessionBank = RequireMachineSession(userId, round.MachineId, createIfMissing: false);
        if (sessionBank.IsMachineClosed || sessionBank.MachineCredits >= MachineCloseCredits)
            throw new InvalidOperationException("Machine closed - take score and cash out to wallet");
        var machineCreditBaseline = (int)Math.Min(sessionBank.MachineCredits, int.MaxValue);

        CleanRoomCard[] alteredDeck;
        lock (store.LedgerSync)
        {
            var ledger = RequireMachineLedger(round.MachineId);
            alteredDeck = MachinePolicy.BuildDoubleUpDeck(
                FiveCardDrawEngine.BuildStandardDeck(),
                round.RoundEntropySeed,
                ledger.RoundsSinceLucky5Hit,
                ledger.NetSinceLastClose,
                round.PolicyMode);
        }

        var session = Lucky5DoubleUpEngine.CreateSessionFromDeck(
            round.RoundEntropySeed,
            FiveCardDrawEngine.ShuffleDeck(round.RoundEntropySeed, "double-up", alteredDeck),
            (int)round.WinAmount,
            machineCreditBaseline);

        round.DoubleUpSession = session;
        round.EnteredDoubleUp = true;
        var noise = GenerateNoise(round.RoundEntropySeed, 0);
        return Task.FromResult(new DoubleUpResultDto(roundId, "Started", session.CurrentAmount, sessionBank.MachineCredits,
            DealerCard: ToCleanRoomDto(session.DealerCard),
            SwitchesRemaining: session.Options.MaxSwitchesPerRound - session.SwitchCountInRound,
            IsNoLoseActive: session.IsNoLoseActive,
            Noise: noise));
    }

    public Task<DoubleUpResultDto> SwitchDealerAsync(Guid userId, Guid roundId, CancellationToken cancellationToken)
    {
        if (!store.ActiveRounds.TryGetValue(roundId, out var round) || round.UserId != userId)
            throw new KeyNotFoundException("Round not found");
        if (round.DoubleUpSession is null)
            throw new InvalidOperationException("Double-up session not started");

        var session = Lucky5DoubleUpEngine.SwitchDealer(round.DoubleUpSession);
        round.DoubleUpSession = session;
        var isLucky = session.DealerCard.Rank == 5 && session.DealerCard.Suit == 'S';
        var luckyMult = 0;
        if (isLucky)
        {
            luckyMult = session.LuckyHitCount == 1 ? session.Options.FirstLuckyMultiplier : session.Options.RepeatLuckyMultiplier;
            lock (store.LedgerSync)
            {
                RequireMachineLedger(round.MachineId).RoundsSinceLucky5Hit = 0;
            }
        }
        var sessionBank = RequireMachineSession(userId, round.MachineId, createIfMissing: false);
        var noise = GenerateNoise(round.RoundEntropySeed, session.CurrentRoundIndex);
        if (session.IsTerminal && session.TerminalOutcome == Lucky5DoubleUpOutcome.MachineClosed)
        {
            FinalizeDoubleUp(round, sessionBank, session.CashoutCredits);
            return Task.FromResult(new DoubleUpResultDto(roundId, "MachineClosed", session.CashoutCredits, sessionBank.MachineCredits,
                DealerCard: ToCleanRoomDto(session.DealerCard),
                SwitchesRemaining: 0,
                IsNoLoseActive: session.IsNoLoseActive,
                LuckyMultiplier: luckyMult,
                Noise: noise));
        }
        return Task.FromResult(new DoubleUpResultDto(roundId, isLucky ? "Lucky5" : "Switched", session.CurrentAmount, sessionBank.MachineCredits,
            DealerCard: ToCleanRoomDto(session.DealerCard),
            SwitchesRemaining: session.Options.MaxSwitchesPerRound - session.SwitchCountInRound,
            IsNoLoseActive: session.IsNoLoseActive,
            LuckyMultiplier: luckyMult,
            Noise: noise));
    }

    public async Task<DoubleUpResultDto> GuessDoubleUpAsync(Guid userId, Guid roundId, string guess, CancellationToken cancellationToken)
    {
        if (!store.ActiveRounds.TryGetValue(roundId, out var round) || round.UserId != userId)
            throw new KeyNotFoundException("Round not found");
        if (round.IsPayoutSettled)
            throw new InvalidOperationException("Payout already settled");
        if (round.DoubleUpSession is null)
        {
            _ = await StartDoubleUpAsync(userId, roundId, cancellationToken);
            round = store.ActiveRounds[roundId];
        }

        var parsedGuess = guess.Equals("big", StringComparison.OrdinalIgnoreCase) ? BigSmallGuess.Big : BigSmallGuess.Small;
        var resolution = Lucky5DoubleUpEngine.ResolveGuess(round.DoubleUpSession!, parsedGuess);
        round.DoubleUpSession = resolution.Session;
        var sessionBank = RequireMachineSession(userId, round.MachineId, createIfMissing: false);
        var noise = GenerateNoise(round.RoundEntropySeed, resolution.Session.CurrentRoundIndex);

switch (resolution.Outcome)
{
    case Lucky5DoubleUpOutcome.Win:
        return new DoubleUpResultDto(
            roundId,
            "Win",
            resolution.NextAmount,
            sessionBank.MachineCredits,
            DealerCard: ToCleanRoomDto(resolution.Session.DealerCard),
            ChallengerCard: ToCleanRoomDto(resolution.ChallengerCard),
            SwitchesRemaining: resolution.Session.Options.MaxSwitchesPerRound - resolution.Session.SwitchCountInRound,
            IsNoLoseActive: false,
            Noise: noise);

    case Lucky5DoubleUpOutcome.SafeFail:
        FinalizeDoubleUp(round, sessionBank, resolution.CashoutCredits);
        return new DoubleUpResultDto(
            roundId,
            "SafeFail",
            resolution.CashoutCredits,
            sessionBank.MachineCredits,
            DealerCard: ToCleanRoomDto(resolution.DealerCard),
            ChallengerCard: ToCleanRoomDto(resolution.ChallengerCard),
            SwitchesRemaining: 0,
            IsNoLoseActive: false,
            Noise: noise);

    case Lucky5DoubleUpOutcome.MachineClosed:
        FinalizeDoubleUp(round, sessionBank, resolution.CashoutCredits);
        return new DoubleUpResultDto(
            roundId,
            "MachineClosed",
            resolution.CashoutCredits,
            sessionBank.MachineCredits,
            DealerCard: ToCleanRoomDto(resolution.DealerCard),
            ChallengerCard: ToCleanRoomDto(resolution.ChallengerCard),
            SwitchesRemaining: 0,
            Noise: noise);

    default:
        FinalizeDoubleUp(round, sessionBank, 0);
        round.WinAmount = 0;
        return new DoubleUpResultDto(
            roundId,
            "Lose",
            0,
            sessionBank.MachineCredits,
            DealerCard: ToCleanRoomDto(resolution.DealerCard),
            ChallengerCard: ToCleanRoomDto(resolution.ChallengerCard),
            SwitchesRemaining: 0,
            Noise: noise);
}
    }

    public Task<DoubleUpResultDto> CashoutDoubleUpAsync(Guid userId, Guid roundId, CancellationToken cancellationToken)
    {
        if (!store.ActiveRounds.TryGetValue(roundId, out var round) || round.UserId != userId)
            throw new KeyNotFoundException("Round not found");
        var session = RequireMachineSession(userId, round.MachineId, createIfMissing: false);
        var cashoutAmount = round.DoubleUpSession != null ? round.DoubleUpSession.CurrentAmount : (int)round.WinAmount;
        if (round.IsPayoutSettled)
            return Task.FromResult(new DoubleUpResultDto(roundId, "Cashout", 0, session.MachineCredits));

        if (round.DoubleUpSession != null && !round.DoubleUpSession.IsTerminal)
        {
            FinalizeDoubleUp(round, session, cashoutAmount);
        }
        else if (round.DoubleUpSession == null)
        {
            session.MachineCredits += cashoutAmount;
            session.LastUpdatedUtc = DateTime.UtcNow;
            round.SettledAmount += cashoutAmount;
            round.IsPayoutSettled = true;
            lock (store.LedgerSync)
            {
                var ledger = RequireMachineLedger(round.MachineId);
                var delta = round.SettledAmount - round.OriginalWinAmount;
                if (delta != 0) ledger.CapitalOut += delta;
                ledger.LastWinChannel = round.JackpotWinAmount > 0 ? WinChannel.Jackpot : WinChannel.BaseGame;
                ledger.NetSinceLastClose = Math.Max(ledger.CapitalIn - ledger.CapitalOut, 0m);
            }
            session.IsMachineClosed = session.MachineCredits >= MachineCloseCredits;
            store.Ledger.Add(new WalletLedgerEntry
            {
                UserId = userId,
                Amount = cashoutAmount,
                BalanceAfter = session.MachineCredits,
                Type = "Cashout",
                Reference = round.RoundId.ToString("N"),
                CreatedUtc = DateTime.UtcNow
            });
        }

        return Task.FromResult(new DoubleUpResultDto(roundId, "Cashout", cashoutAmount, session.MachineCredits));
    }

    public Task<DoubleUpResultDto> TakeHalfAsync(Guid userId, Guid roundId, CancellationToken cancellationToken)
    {
        if (!store.ActiveRounds.TryGetValue(roundId, out var round) || round.UserId != userId)
            throw new KeyNotFoundException("Round not found");
        if (round.IsPayoutSettled)
            throw new InvalidOperationException("Payout already settled");
        if (round.TakeHalfUsed)
            throw new InvalidOperationException("Take-half already used this round");
        var session = RequireMachineSession(userId, round.MachineId, createIfMissing: false);
        var currentAmount = round.DoubleUpSession != null ? round.DoubleUpSession.CurrentAmount : (int)round.WinAmount;
        if (currentAmount <= 1) throw new InvalidOperationException("Amount too small to split");

        var half = currentAmount / 2;
        var remaining = currentAmount - half;
        session.MachineCredits += half;
        session.LastUpdatedUtc = DateTime.UtcNow;
        session.IsMachineClosed = session.MachineCredits >= MachineCloseCredits;
        round.SettledAmount += half;
        round.TakeHalfUsed = true;
        if (round.DoubleUpSession != null) round.DoubleUpSession = round.DoubleUpSession with { CurrentAmount = remaining };
        else round.WinAmount = remaining;

        store.Ledger.Add(new WalletLedgerEntry
        {
            UserId = userId,
            Amount = half,
            BalanceAfter = session.MachineCredits,
            Type = "TakeHalf",
            Reference = round.RoundId.ToString("N"),
            CreatedUtc = DateTime.UtcNow
        });

        return Task.FromResult(new DoubleUpResultDto(roundId, "TakeHalf", remaining, session.MachineCredits));
    }

    public Task<JackpotInfoDto> ChangeJackpotRankAsync(int machineId, int rank, CancellationToken cancellationToken)
    {
        if (rank < 2 || rank > 14) throw new ArgumentException("Rank must be between 2 and 14");
        lock (store.LedgerSync)
        {
            var ledger = RequireMachineLedger(machineId);
            ledger.JackpotFullHouseRank = rank;
            return Task.FromResult(SnapshotJackpots(ledger));
        }
    }

    public Task<object> GetMachineStateAsync(int machineId, CancellationToken cancellationToken)
    {
        var ledger = RequireMachineLedger(machineId);
        var activeRounds = store.ActiveRounds.Values.Count(x => x.MachineId == machineId && !x.IsCompleted);
        var activeSessions = store.MachineSessions.Values.Count(x => x.MachineId == machineId && x.MachineCredits > 0);
        return Task.FromResult<object>(new
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
        });
    }

    public Task<object> ResetMachineAsync(Guid userId, int machineId, CancellationToken cancellationToken)
    {
        _ = RequireProfile(userId);
        lock (store.LedgerSync)
        {
            var ledger = RequireMachineLedger(machineId);
            ledger.CapitalIn = 0;
            ledger.CapitalOut = 0;
            ledger.BaseCapitalOut = 0;
            ledger.RoundCount = 0;
            ledger.ConsecutiveLosses = 0;
            ledger.RoundsSinceMediumWin = 0;
            ledger.CooldownRoundsRemaining = 0;
            ledger.NetSinceLastClose = 0;
            ledger.LastCloseRoundNumber = 0;
            ledger.RoundsSinceLucky5Hit = 0;
            ledger.LastPayoutScale = 2.37m;
            ledger.LastDistributionMode = DistributionMode.Neutral;
            ledger.JackpotFullHouse = 5_000_000m;
            ledger.JackpotFullHouseRank = 14;
            ledger.JackpotFourOfAKindA = 200_000m;
            ledger.JackpotFourOfAKindB = 200_000m;
            ledger.JackpotStraightFlush = 4_000_000m;
            ledger.ActiveFourOfAKindSlot = 0;
        }
        return Task.FromResult<object>(new { success = true, message = "Machine state reset" });
    }

    private void FinalizeDoubleUp(GameRound round, MachineSessionState session, int cashoutCredits)
    {
        session.MachineCredits += cashoutCredits;
        session.LastUpdatedUtc = DateTime.UtcNow;
        session.IsMachineClosed = session.MachineCredits >= MachineCloseCredits;
        round.IsPayoutSettled = true;
        round.SettledAmount += cashoutCredits;
        var ledgerDelta = round.SettledAmount - round.OriginalWinAmount;
        lock (store.LedgerSync)
        {
            var ledger = RequireMachineLedger(round.MachineId);
            if (ledgerDelta != 0) ledger.CapitalOut += ledgerDelta;
            if (cashoutCredits > round.OriginalWinAmount) ledger.LastWinChannel = WinChannel.DoubleUp;
            else if (round.JackpotWinAmount > 0) ledger.LastWinChannel = WinChannel.Jackpot;
            else if (cashoutCredits > 0) ledger.LastWinChannel = WinChannel.BaseGame;
            else ledger.LastWinChannel = WinChannel.None;
            ledger.NetSinceLastClose = Math.Max(ledger.CapitalIn - ledger.CapitalOut, 0m);
        }
        store.Ledger.Add(new WalletLedgerEntry
        {
            UserId = round.UserId,
            Amount = cashoutCredits,
            BalanceAfter = session.MachineCredits,
            Type = cashoutCredits > 0 ? "DoubleUpCashout" : "DoubleUpLoss",
            Reference = round.RoundId.ToString("N"),
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

    private static PokerCardDto ToDto(PokerCard c) => new(c.Rank, c.Suit, c.Code);
    private static PokerCardDto ToCleanRoomDto(CleanRoomCard c)
    {
        var rank = CleanRoomCard.GetLegacyRank(c.Rank);
        var suit = c.Suit.ToString();
        return new PokerCardDto(rank, suit, $"{rank}{suit}");
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

    private Machine RequireMachine(int machineId)
    {
        var machine = store.Machines.FirstOrDefault(m => m.Id == machineId && m.IsOpen);
        if (machine is null) throw new KeyNotFoundException("Machine not found");
        return machine;
    }

    private MachineLedgerState RequireMachineLedger(int machineId)
    {
        if (!store.MachineLedgers.TryGetValue(machineId, out var ledger)) throw new KeyNotFoundException("Machine ledger not found");
        return ledger;
    }

    private MemberProfile RequireProfile(Guid userId)
    {
        if (!store.Profiles.TryGetValue(userId, out var profile)) throw new KeyNotFoundException("Profile not found");
        return profile;
    }

    private MachineSessionState RequireMachineSession(Guid userId, int machineId, bool createIfMissing)
    {
        var key = $"{userId:N}:{machineId}";
        if (store.MachineSessions.TryGetValue(key, out var existing)) return existing;
        if (!createIfMissing) throw new KeyNotFoundException("Machine session not found");
        var session = new MachineSessionState { UserId = userId, MachineId = machineId };
        store.MachineSessions[key] = session;
        return session;
    }

    private static bool CanCashOut(MachineSessionState session)
        => session.IsMachineClosed || (session.TotalCashIn > 0 && session.MachineCredits >= session.TotalCashIn * 2m);

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

    private static MachineSessionDto ToMachineSessionDto(MachineSessionState session, decimal walletBalance)
        => new(session.SessionId, session.MachineId, session.MachineCredits, session.TotalCashIn, session.TotalCashIn * 2m, CanCashOut(session), session.IsMachineClosed, walletBalance);
}
