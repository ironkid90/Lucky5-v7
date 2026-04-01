namespace Lucky5.Infrastructure.Services;

using Lucky5.Application.Contracts;
using Lucky5.Application.Dtos;
using Lucky5.Application.Requests;
using Lucky5.Application.Interfaces;
using Lucky5.Domain.Entities;
using Lucky5.Domain.Game.CleanRoom;

public sealed class GameServiceSimple(IDataStore store, IEntropyGenerator entropyGenerator) : IGameService
{
    private const decimal CashInUnit = 200_000m;
    private const decimal MaxSessionCashIn = 1_000_000m;
    private static readonly EngineConfig EngineCfg = EngineConfig.Default;
    private static readonly decimal MachineCloseCredits = EngineCfg.CloseThreshold;

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
    {
        var machines = await store.GetMachinesAsync(cancellationToken);
        return machines.Select(x => new MachineListingDto(x.Id, x.Name, x.IsOpen, x.MinBet, x.MaxBet)).ToArray();
    }

    public Task<DefaultRulesDto> GetDefaultRulesAsync(CancellationToken cancellationToken)
        => Task.FromResult(new DefaultRulesDto(new Dictionary<string, decimal>(Rules)));

    public async Task<IReadOnlyList<OfferDto>> GetOffersAsync(CancellationToken cancellationToken)
    {
        // For now, return empty offers since we don't have this in IDataStore yet
        return [];
    }

    public async Task<MachineSessionDto> GetMachineSessionAsync(Guid userId, int machineId, CancellationToken cancellationToken)
    {
        var profile = await store.RequireProfileAsync(userId, cancellationToken);
        var session = await store.RequireMachineSessionAsync(userId, machineId, createIfMissing: true, cancellationToken);
        var memberProfile = await store.GetMemberProfileAsync(userId, cancellationToken);
        var walletBalance = memberProfile?.WalletBalance ?? 0;
        return ToMachineSessionDto(session, walletBalance);
    }

    public async Task<MachineSessionDto> CashInAsync(Guid userId, int machineId, decimal amount, CancellationToken cancellationToken)
    {
        var profile = await store.RequireProfileAsync(userId, cancellationToken);
        await store.RequireMachineAsync(machineId, cancellationToken);
        var session = await store.RequireMachineSessionAsync(userId, machineId, createIfMissing: true, cancellationToken);

        if (amount < CashInUnit || amount > MaxSessionCashIn || amount % CashInUnit != 0)
            throw new InvalidOperationException("Cash in must be in 200,000 increments up to 1,000,000");

        session.MachineCredits += amount;
        var memberProfile = await store.GetMemberProfileAsync(userId, cancellationToken);
        
        if (memberProfile != null)
        {
            memberProfile.WalletBalance -= amount;
            await store.UpdateMemberProfileAsync(memberProfile, cancellationToken);
        }

        await store.UpdateMachineSessionAsync(session, cancellationToken);
        return ToMachineSessionDto(session, memberProfile?.WalletBalance ?? 0);
    }

    public async Task<MachineSessionDto> CashOutAsync(Guid userId, int machineId, CancellationToken cancellationToken)
    {
        var session = await store.RequireMachineSessionAsync(userId, machineId, createIfMissing: false, cancellationToken);
        if (session.MachineCredits <= 0)
            throw new InvalidOperationException("No machine credits to cash out");

        var amount = session.MachineCredits;
        session.MachineCredits = 0;
        session.IsMachineClosed = false;

        var memberProfile = await store.GetMemberProfileAsync(userId, cancellationToken);
        if (memberProfile != null)
        {
            memberProfile.WalletBalance += amount;
            await store.UpdateMemberProfileAsync(memberProfile, cancellationToken);
        }

        await store.UpdateMachineSessionAsync(session, cancellationToken);
        return ToMachineSessionDto(session, memberProfile?.WalletBalance ?? 0);
    }

    public async Task<DealResultDto> DealAsync(Guid userId, DealRequest request, CancellationToken cancellationToken)
    {
        var machine = await store.RequireMachineAsync(request.MachineId, cancellationToken);
        var session = await store.RequireMachineSessionAsync(userId, request.MachineId, createIfMissing: true, cancellationToken);
        
        if (session.IsMachineClosed)
            throw new InvalidOperationException("Machine is closed - cash out to wallet before continuing");
        if (request.BetAmount <= 0 || request.BetAmount < machine.MinBet || request.BetAmount > machine.MaxBet)
            throw new InvalidOperationException("Bet amount is outside machine limits");
        if (session.MachineCredits < request.BetAmount * 2m)
            throw new InvalidOperationException("Insufficient machine credits for deal and draw - cash in from wallet first");

        // Simple implementation - create a basic hand
        var seed = entropyGenerator.CreateSeed(userId, request.MachineId, request.BetAmount, new MachineLedgerState());
        var standardDeck = FiveCardDrawEngine.BuildStandardDeck();
        var shuffledDeck = FiveCardDrawEngine.ShuffleDeck(seed, "hand", standardDeck);
        var hand = shuffledDeck.Take(5).ToArray();
        var drawState = FiveCardDrawState.Create(seed, shuffledDeck, hand);

        session.MachineCredits -= request.BetAmount;

        var cards = hand.Select(c => c.ToLegacyPokerCard()).ToList();
        var round = new GameRound
        {
            RoundId = Guid.NewGuid(),
            UserId = userId,
            MachineId = request.MachineId,
            BetAmount = request.BetAmount,
            InitialCards = cards,
            FinalCards = cards,
            CreatedUtc = DateTime.UtcNow,
            CleanRoomState = drawState
        };

        await store.SaveRoundAsync(round, cancellationToken);

        var jackpots = new JackpotInfoDto(0, 0, 0, 0, 0, 0);
        var advisedHolds = FiveCardDrawEngine.ComputeAdvisedHolds(hand);
        return new DealResultDto(round.RoundId, cards.Select(ToDto).ToArray(), request.BetAmount, session.MachineCredits, jackpots, advisedHolds);
    }

    public async Task<DrawResultDto> DrawAsync(Guid userId, DrawRequest request, CancellationToken cancellationToken)
    {
        var round = await store.GetRoundAsync(request.RoundId, cancellationToken);
        if (round == null || round.UserId != userId)
            throw new KeyNotFoundException("Round not found");
        if (round.IsCompleted)
            throw new InvalidOperationException("Round already completed");

        var session = await store.RequireMachineSessionAsync(userId, round.MachineId, createIfMissing: false, cancellationToken);
        if (session.IsMachineClosed)
            throw new InvalidOperationException("Machine is closed - cash out to wallet before continuing");
        if (session.MachineCredits < round.BetAmount)
            throw new InvalidOperationException("Not enough machine credits for draw");

        session.MachineCredits -= round.BetAmount;

        // Simple implementation - just return the same cards for now
        var evaluation = FiveCardDrawEngine.EvaluateHand(round.CleanRoomState!.Hand);
        var basePayout = FiveCardDrawEngine.ResolvePayout(evaluation, (int)round.BetAmount);

        round.IsCompleted = true;
        round.FinalCards = round.InitialCards;
        round.SettledAmount = basePayout;

        await store.SaveRoundAsync(round, cancellationToken);

        var memberProfile = await store.GetMemberProfileAsync(userId, cancellationToken);
        if (memberProfile != null && basePayout > 0)
        {
            memberProfile.WalletBalance += basePayout;
            await store.UpdateMemberProfileAsync(memberProfile, cancellationToken);
        }

        return new DrawResultDto(round.RoundId, round.FinalCards.Select(ToDto).ToArray(), evaluation.ToString(), basePayout, session.MachineCredits);
    }

    public async Task<ActiveRoundStateDto?> GetActiveRoundAsync(Guid userId, int machineId, CancellationToken cancellationToken)
    {
        var round = await store.GetLatestRoundAsync(userId, machineId, cancellationToken);
        if (round == null || round.IsCompleted)
            return null;

        return new ActiveRoundStateDto(
            round.RoundId,
            round.MachineId,
            round.BetAmount,
            round.HandRank,
            round.InitialCards.Select(ToDto).ToArray(),
            round.CleanRoomState != null ? FiveCardDrawEngine.ComputeAdvisedHolds(round.CleanRoomState.Hand) : [],
            round.SettledAmount,
            null
        );
    }

    public async Task<object> GetMachineStateAsync(int machineId, CancellationToken cancellationToken)
    {
        var machine = await store.RequireMachineAsync(machineId, cancellationToken);
        var sessions = await store.GetMachineSessionsAsync(machineId, cancellationToken);
        
        return new
        {
            MachineId = machine.Id,
            Name = machine.Name,
            IsOpen = machine.IsOpen,
            ActiveSessions = sessions.Count,
            TotalCredits = sessions.Sum(s => s.MachineCredits)
        };
    }

    // Double-up methods - simplified implementations
    public async Task<DoubleUpResultDto> StartDoubleUpAsync(Guid userId, Guid roundId, CancellationToken cancellationToken)
    {
        var round = await store.GetRoundAsync(roundId, cancellationToken);
        if (round == null || round.UserId != userId || round.IsCompleted || round.SettledAmount <= 0)
            throw new InvalidOperationException("Invalid round for double-up");

        return new DoubleUpResultDto(roundId, round.SettledAmount, "High", null, "Double-up started");
    }

    public async Task<DoubleUpResultDto> SwitchDealerAsync(Guid userId, Guid roundId, CancellationToken cancellationToken)
    {
        return await StartDoubleUpAsync(userId, roundId, cancellationToken);
    }

    public async Task<DoubleUpResultDto> GuessDoubleUpAsync(Guid userId, Guid roundId, string guess, CancellationToken cancellationToken)
    {
        var round = await store.GetRoundAsync(roundId, cancellationToken);
        if (round == null || round.UserId != userId)
            throw new KeyNotFoundException("Round not found");

        // Simplified - just return the current amount
        return new DoubleUpResultDto(roundId, round.SettledAmount, guess, null, "Double-up complete");
    }

    public async Task<DoubleUpResultDto> CashoutDoubleUpAsync(Guid userId, Guid roundId, CancellationToken cancellationToken)
    {
        var round = await store.GetRoundAsync(roundId, cancellationToken);
        if (round == null || round.UserId != userId)
            throw new KeyNotFoundException("Round not found");

        return new DoubleUpResultDto(roundId, round.SettledAmount, "High", null, "Double-up cashed out");
    }

    public async Task<DoubleUpResultDto> TakeHalfAsync(Guid userId, Guid roundId, CancellationToken cancellationToken)
    {
        var round = await store.GetRoundAsync(roundId, cancellationToken);
        if (round == null || round.UserId != userId)
            throw new KeyNotFoundException("Round not found");

        var halfAmount = round.SettledAmount / 2;
        return new DoubleUpResultDto(roundId, halfAmount, "High", null, "Half taken");
    }

    public async Task<JackpotInfoDto> ChangeJackpotRankAsync(int machineId, int rank, CancellationToken cancellationToken)
    {
        await store.RequireMachineAsync(machineId, cancellationToken);
        return new JackpotInfoDto(0, 0, 0, 0, 0);
    }

    public async Task<object> ResetMachineAsync(Guid userId, int machineId, CancellationToken cancellationToken)
    {
        await store.RequireMachineAsync(machineId, cancellationToken);
        await store.ClearActiveRoundsAsync(cancellationToken);
        return new { MachineId = machineId, ResetAt = DateTime.UtcNow };
    }

    private static MachineSessionDto ToMachineSessionDto(MachineSessionState session, decimal walletBalance)
        => new(session.SessionId, session.MachineId, session.MachineCredits, walletBalance, session.IsMachineClosed, true, 0, session.TotalCashIn);

    private static PokerCardDto ToDto(PokerCard card)
        => new(card.Suit.ToString(), card.Rank.ToString(), card.ToString());
}
