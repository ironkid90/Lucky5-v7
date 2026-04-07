namespace Lucky5.Tests;

using System.Threading;
using Lucky5.Application.Contracts;
using Lucky5.Application.Dtos;
using Lucky5.Application.Requests;
using Lucky5.Domain.Entities;
using Lucky5.Domain.Game.CleanRoom;
using Lucky5.Infrastructure.Data.Repositories;
using Lucky5.Infrastructure.Services;

public static class GameServiceRegressionTests
{
    public static async Task RunAsync(List<string> failures)
    {
        await FourOfAKindSlotIsCapturedAtomicallyAtDealAsync(failures);
        await MachineSessionCashOutEligibilityFollowsRulesAsync(failures);
        await CashOutRejectsBelowThresholdWhenMachineIsNotClosedAsync(failures);
        await CompletedButUnsettledRoundRemainsRecoverableAsync(failures);
        await GetActiveRoundRestoresDealtPhaseAsync(failures);
        await GetActiveRoundKeepsDrawnStateUntilPayoutSettledAsync(failures);
        await GetActiveRoundRestoresActiveDoubleUpPhaseAsync(failures);
        await ClosedMachineCashOutIsIdempotentAsync(failures);
        await PlayerResetAfterCloseAutoCashesOutAndClearsSessionAsync(failures);
        await PlayerResetBlocksRecoverableRoundAsync(failures);
        await AdminResetBlocksRecoverableRoundsAsync(failures);
        await AdminResetAllowsClosedSessionsWithoutActiveRoundsAsync(failures);
    }

    private static async Task FourOfAKindSlotIsCapturedAtomicallyAtDealAsync(List<string> failures)
    {
        using var seedRequested = new ManualResetEventSlim(false);
        using var mutationApplied = new ManualResetEventSlim(false);
        using var releaseMutation = new ManualResetEventSlim(false);

        const ulong fixedSeed = 0UL;
        const int mutatedSlot = 0;
        var expectedSlot = 1 - (int)(fixedSeed % 2);

        var store = new InMemoryDataStore();
        var service = new GameService(new InMemoryDataStoreAdapter(store), new SignalingEntropyGenerator(fixedSeed, seedRequested));

        var userId = Guid.Parse("10000000-0000-0000-0000-000000000001");
        SeedPlayer(store, userId, "slot-race", 2_000_000m);

        var machineId = store.Machines.Values.First(machine => machine.IsOpen).Id;
        var minBet = store.Machines[machineId].MinBet;
        await service.CashInAsync(userId, machineId, 200_000m, CancellationToken.None);

        var mutationTask = Task.Run(() =>
        {
            if (!seedRequested.Wait(TimeSpan.FromSeconds(5)))
            {
                return;
            }

            lock (store.LedgerSync)
            {
                store.MachineLedgers[machineId].ActiveFourOfAKindSlot = mutatedSlot;
                mutationApplied.Set();
                releaseMutation.Wait(TimeSpan.FromSeconds(5));
            }
        });

        var dealTask = Task.Run(() => service.DealAsync(userId, new DealRequest(machineId, minBet), CancellationToken.None));

        if (!mutationApplied.Wait(TimeSpan.FromSeconds(5)))
        {
            failures.Add("Regression test setup failed to interleave the Four-of-a-Kind slot mutation during deal.");
            releaseMutation.Set();
            await mutationTask;
            await dealTask;
            return;
        }

        releaseMutation.Set();

        var deal = await dealTask;
        await mutationTask;

        var round = store.ActiveRounds[deal.RoundId];
        if (round.ActiveFourOfAKindSlotAtDeal != expectedSlot)
        {
            failures.Add($"Four-of-a-Kind slot should stay at the deal-time value {expectedSlot}, but was captured as {round.ActiveFourOfAKindSlotAtDeal} after a concurrent ledger mutation.");
        }
    }

    private static async Task MachineSessionCashOutEligibilityFollowsRulesAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var service = new GameService(new InMemoryDataStoreAdapter(store), new DefaultEntropyGenerator());
        var userId = Guid.Parse("20000000-0000-0000-0000-000000000001");

        SeedPlayer(store, userId, "cashout-rules", 2_000_000m);

        var machineId = store.Machines.Values.First(machine => machine.IsOpen).Id;
        await service.CashInAsync(userId, machineId, 200_000m, CancellationToken.None);

        var sessionDto = await service.GetMachineSessionAsync(userId, machineId, CancellationToken.None);
        Assert(
            failures,
            "Machine session should not be cash-out eligible before reaching the 2x threshold or a machine-close event.",
            !sessionDto.CanCashOut);

        var session = GetSession(store, userId, machineId);
        session.MachineCredits = 400_000m;
        session.LastUpdatedUtc = DateTime.UtcNow;

        sessionDto = await service.GetMachineSessionAsync(userId, machineId, CancellationToken.None);
        Assert(
            failures,
            "Machine session should become cash-out eligible once credits reach the documented 2x threshold.",
            sessionDto.CanCashOut);

        session.MachineCredits = 250_000m;
        session.IsMachineClosed = true;
        session.LastUpdatedUtc = DateTime.UtcNow;

        sessionDto = await service.GetMachineSessionAsync(userId, machineId, CancellationToken.None);
        Assert(
            failures,
            "Machine session should remain cash-out eligible after a machine-close event even if credits fall below the 2x threshold.",
            sessionDto.CanCashOut);
    }

    private static async Task CashOutRejectsBelowThresholdWhenMachineIsNotClosedAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var service = new GameService(new InMemoryDataStoreAdapter(store), new DefaultEntropyGenerator());
        var userId = Guid.Parse("20000000-0000-0000-0000-000000000002");

        SeedPlayer(store, userId, "cashout-blocked", 2_000_000m);

        var machineId = store.Machines.Values.First(machine => machine.IsOpen).Id;
        await service.CashInAsync(userId, machineId, 200_000m, CancellationToken.None);

        var blocked = false;
        try
        {
            await service.CashOutAsync(userId, machineId, CancellationToken.None);
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("only available", StringComparison.Ordinal))
        {
            blocked = true;
        }

        Assert(
            failures,
            "CashOutAsync should reject sessions that are below the 2x threshold and not machine-closed.",
            blocked);
    }

    private static async Task CompletedButUnsettledRoundRemainsRecoverableAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var service = new GameService(new InMemoryDataStoreAdapter(store), new DefaultEntropyGenerator());
        var userId = Guid.Parse("20000000-0000-0000-0000-000000000003");

        SeedPlayer(store, userId, "recover-drawn", 2_000_000m);

        var machineId = store.Machines.Values.First(machine => machine.IsOpen).Id;
        var round = new GameRound
        {
            RoundId = Guid.Parse("30000000-0000-0000-0000-000000000001"),
            UserId = userId,
            MachineId = machineId,
            BetAmount = 5_000m,
            HandRank = "TwoPair",
            WinAmount = 10_000m,
            OriginalWinAmount = 10_000m,
            IsCompleted = true,
            IsPayoutSettled = false,
            CleanRoomState = CreateState(
                RoundPhase.Drawn,
                RoundState.Evaluate,
                ["AS", "AD", "8C", "8H", "2S"])
        };

        store.ActiveRounds[round.RoundId] = round;

        var active = await service.GetActiveRoundAsync(userId, machineId, CancellationToken.None);
        Assert(
            failures,
            "GetActiveRoundAsync should return completed-but-unsettled winning rounds so refresh/reconnect can restore them.",
            active is not null);

        if (active is null)
        {
            return;
        }

        Assert(
            failures,
            "Recoverable winning rounds should hydrate as Drawn.",
            string.Equals(active.Phase, "Drawn", StringComparison.Ordinal));
        Assert(
            failures,
            "Recoverable drawn rounds should preserve the pending win amount.",
            active.PendingWinAmount == round.WinAmount);
    }

    private static async Task GetActiveRoundRestoresDealtPhaseAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var service = new GameService(new InMemoryDataStoreAdapter(store), new DefaultEntropyGenerator());
        var userId = Guid.Parse("20000000-0000-0000-0000-000000000004");

        SeedPlayer(store, userId, "recover-dealt", 2_000_000m);

        var machineId = store.Machines.Values.First(machine => machine.IsOpen).Id;
        var dealt = CreateState(
            RoundPhase.Dealt,
            RoundState.Deal,
            ["AS", "KD", "QH", "JC", "10S"],
            held: [true, false, true, false, true]);

        var round = new GameRound
        {
            RoundId = Guid.Parse("30000000-0000-0000-0000-000000000002"),
            UserId = userId,
            MachineId = machineId,
            BetAmount = 5_000m,
            InitialCards = dealt.Hand.Select(card => card.ToLegacyPokerCard()).ToList(),
            FinalCards = dealt.Hand.Select(card => card.ToLegacyPokerCard()).ToList(),
            IsCompleted = false,
            IsPayoutSettled = false,
            CleanRoomState = dealt
        };

        store.ActiveRounds[round.RoundId] = round;

        var active = await service.GetActiveRoundAsync(userId, machineId, CancellationToken.None);
        Assert(
            failures,
            "GetActiveRoundAsync should restore dealt rounds during reconnect hydration.",
            active is not null);

        if (active is null)
        {
            return;
        }

        Assert(
            failures,
            "Reconnect hydration should report a dealt round as phase 'Dealt'.",
            string.Equals(active.Phase, "Dealt", StringComparison.Ordinal));
        Assert(
            failures,
            "Reconnect hydration should preserve held indexes for dealt rounds.",
            active.HeldIndexes.SequenceEqual([0, 2, 4]));
    }

    private static async Task GetActiveRoundKeepsDrawnStateUntilPayoutSettledAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var service = new GameService(new InMemoryDataStoreAdapter(store), new DefaultEntropyGenerator());
        var userId = Guid.Parse("20000000-0000-0000-0000-000000000005");

        SeedPlayer(store, userId, "reconnect-drawn", 2_000_000m);

        var machineId = store.Machines.Values.First(machine => machine.IsOpen).Id;
        var drawn = CreateState(
            RoundPhase.Drawn,
            RoundState.Evaluate,
            ["AH", "AD", "8C", "8H", "2S"]);

        var round = new GameRound
        {
            RoundId = Guid.Parse("30000000-0000-0000-0000-000000000003"),
            UserId = userId,
            MachineId = machineId,
            BetAmount = store.Machines[machineId].MinBet,
            InitialCards = drawn.Hand.Select(card => card.ToLegacyPokerCard()).ToList(),
            FinalCards = drawn.Hand.Select(card => card.ToLegacyPokerCard()).ToList(),
            HandRank = "TwoPair",
            WinAmount = 10_000m,
            OriginalWinAmount = 10_000m,
            IsCompleted = true,
            IsPayoutSettled = false,
            CleanRoomState = drawn
        };

        store.ActiveRounds[round.RoundId] = round;

        var active = await service.GetActiveRoundAsync(userId, machineId, CancellationToken.None);
        Assert(
            failures,
            "GetActiveRoundAsync should keep a drawn round available until the payout is settled.",
            active is not null);

        if (active is null)
        {
            return;
        }

        Assert(
            failures,
            "Reconnect hydration should report a drawn round as phase 'Drawn'.",
            string.Equals(active.Phase, "Drawn", StringComparison.Ordinal));
        Assert(
            failures,
            "Reconnect hydration should preserve the pending win amount for drawn rounds.",
            active.PendingWinAmount == round.WinAmount);
    }

    private static async Task GetActiveRoundRestoresActiveDoubleUpPhaseAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var service = new GameService(new InMemoryDataStoreAdapter(store), new DefaultEntropyGenerator());
        var userId = Guid.Parse("20000000-0000-0000-0000-000000000006");

        SeedPlayer(store, userId, "reconnect-doubleup", 2_000_000m);

        var machineId = store.Machines.Values.First(machine => machine.IsOpen).Id;
        var drawn = CreateState(
            RoundPhase.Drawn,
            RoundState.Evaluate,
            ["AH", "AD", "8C", "8H", "2S"]);
        var duSession = Lucky5DoubleUpEngine.CreateSessionFromDeck(
            seedRoot: 0xD0B1EUL,
            deck: FiveCardDrawEngine.ParseCards(["9H", "AS", "4C", "2D"]),
            openingAmount: 10_000,
            machineCreditBaseline: 500_000);

        var round = new GameRound
        {
            RoundId = Guid.Parse("30000000-0000-0000-0000-000000000004"),
            UserId = userId,
            MachineId = machineId,
            BetAmount = 5_000m,
            InitialCards = drawn.Hand.Select(card => card.ToLegacyPokerCard()).ToList(),
            FinalCards = drawn.Hand.Select(card => card.ToLegacyPokerCard()).ToList(),
            HandRank = "TwoPair",
            WinAmount = 10_000m,
            OriginalWinAmount = 10_000m,
            IsCompleted = true,
            IsPayoutSettled = false,
            DoubleUpOffered = true,
            DoubleUpSession = duSession,
            CleanRoomState = drawn
        };

        store.ActiveRounds[round.RoundId] = round;

        var active = await service.GetActiveRoundAsync(userId, machineId, CancellationToken.None);
        Assert(
            failures,
            "GetActiveRoundAsync should restore active double-up sessions during reconnect hydration.",
            active is not null);

        if (active is null)
        {
            return;
        }

        Assert(
            failures,
            "Reconnect hydration should report an in-progress double-up as phase 'DoubleUp'.",
            string.Equals(active.Phase, "DoubleUp", StringComparison.Ordinal));
        Assert(
            failures,
            "Reconnect hydration should preserve the current double-up amount.",
            active.DoubleUpSession is not null && active.DoubleUpSession.CurrentAmount == duSession.CurrentAmount);
    }

    private static async Task ClosedMachineCashOutIsIdempotentAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var service = new GameService(new InMemoryDataStoreAdapter(store), new DefaultEntropyGenerator());
        var userId = Guid.Parse("20000000-0000-0000-0000-000000000007");

        SeedPlayer(store, userId, "idempotent-cashout", 2_000_000m);

        var machineId = store.Machines.Values.First(machine => machine.IsOpen).Id;
        var session = new MachineSessionState
        {
            UserId = userId,
            MachineId = machineId,
            MachineCredits = 1_000_000m,
            TotalCashIn = 1_000_000m,
            IsMachineClosed = true,
            LastUpdatedUtc = DateTime.UtcNow
        };
        store.MachineSessions[session.SessionId] = session;

        var walletBefore = store.MemberProfiles[userId].WalletBalance;
        var first = await service.CashOutAsync(userId, machineId, CancellationToken.None);
        Assert(
            failures,
            "First cash-out should fully drain machine credits and reopen the closed session.",
            first.MachineCredits == 0m && !first.IsMachineClosed);
        Assert(
            failures,
            "First cash-out should return the drained amount to the wallet.",
            first.WalletBalance == walletBefore + 1_000_000m);

        var threw = false;
        MachineSessionDto? second = null;
        try
        {
            second = await service.CashOutAsync(userId, machineId, CancellationToken.None);
        }
        catch (InvalidOperationException)
        {
            threw = true;
        }

        Assert(
            failures,
            "Repeated cash-out on an already drained closed session should be idempotent and not throw.",
            !threw);
        Assert(
            failures,
            "Repeated cash-out on an already drained closed session should leave the session drained.",
            second is not null && second.MachineCredits == 0m && !second.IsMachineClosed && second.WalletBalance == first.WalletBalance);
    }

    private static async Task PlayerResetAfterCloseAutoCashesOutAndClearsSessionAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var service = new GameService(new InMemoryDataStoreAdapter(store), new DefaultEntropyGenerator());
        var userId = Guid.Parse("20000000-0000-0000-0000-000000000008");

        SeedPlayer(store, userId, "player-reset", 500_000m);

        var machineId = store.Machines.Values.First(machine => machine.IsOpen).Id;
        store.MachineLedgers[machineId].CapitalIn = 900_000m;
        store.MachineLedgers[machineId].CapitalOut = 700_000m;

        var session = new MachineSessionState
        {
            UserId = userId,
            MachineId = machineId,
            MachineCredits = 40_000_000m,
            TotalCashIn = 1_000_000m,
            IsMachineClosed = true,
            CounterplayScore = 3,
            LastUpdatedUtc = DateTime.UtcNow
        };
        store.MachineSessions[session.SessionId] = session;

        var walletBefore = store.MemberProfiles[userId].WalletBalance;
        await service.ResetMachineAsync(userId, machineId, CancellationToken.None);

        Assert(
            failures,
            "Player machine reset after close should auto-cash-out the closed machine balance.",
            store.MemberProfiles[userId].WalletBalance == walletBefore + 40_000_000m);
        Assert(
            failures,
            "Player machine reset after close should delete the stale machine session.",
            !store.MachineSessions.Values.Any(existing => existing.UserId == userId && existing.MachineId == machineId));
        Assert(
            failures,
            "Player machine reset should preserve the machine ledger because machine close is gameplay state, not a hidden ledger reset.",
            store.MachineLedgers[machineId].CapitalIn == 900_000m && store.MachineLedgers[machineId].CapitalOut == 700_000m);
    }

    private static async Task PlayerResetBlocksRecoverableRoundAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var service = new GameService(new InMemoryDataStoreAdapter(store), new DefaultEntropyGenerator());
        var userId = Guid.Parse("20000000-0000-0000-0000-000000000009");

        SeedPlayer(store, userId, "blocked-reset", 2_000_000m);

        var machineId = store.Machines.Values.First(machine => machine.IsOpen).Id;
        store.ActiveRounds[Guid.Parse("30000000-0000-0000-0000-000000000005")] = new GameRound
        {
            RoundId = Guid.Parse("30000000-0000-0000-0000-000000000005"),
            UserId = userId,
            MachineId = machineId,
            BetAmount = 5_000m,
            HandRank = "TwoPair",
            WinAmount = 10_000m,
            OriginalWinAmount = 10_000m,
            IsCompleted = true,
            IsPayoutSettled = false,
            CleanRoomState = CreateState(RoundPhase.Drawn, RoundState.Evaluate, ["AS", "AD", "8C", "8H", "2S"])
        };

        var blocked = false;
        try
        {
            await service.ResetMachineAsync(userId, machineId, CancellationToken.None);
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("active round", StringComparison.Ordinal))
        {
            blocked = true;
        }

        Assert(
            failures,
            "Player machine reset should reject recoverable rounds instead of silently discarding them.",
            blocked);
    }

    private static async Task AdminResetBlocksRecoverableRoundsAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var adminService = new AdminService(store, new NoOpPersistentStateStore());
        var adminId = Guid.Parse("20000000-0000-0000-0000-000000000010");
        var userId = Guid.Parse("20000000-0000-0000-0000-000000000011");

        SeedPlayer(store, adminId, "recover-admin", 500_000m, role: "Admin");
        SeedPlayer(store, userId, "recoverable-round", 2_000_000m);

        var machineId = store.Machines.Values.First(machine => machine.IsOpen).Id;
        store.ActiveRounds[Guid.Parse("30000000-0000-0000-0000-000000000006")] = new GameRound
        {
            RoundId = Guid.Parse("30000000-0000-0000-0000-000000000006"),
            UserId = userId,
            MachineId = machineId,
            BetAmount = 5_000m,
            HandRank = "FullHouse",
            WinAmount = 60_000m,
            OriginalWinAmount = 60_000m,
            IsCompleted = true,
            IsPayoutSettled = false,
            CleanRoomState = CreateState(RoundPhase.Drawn, RoundState.Evaluate, ["AH", "AD", "AC", "KH", "KD"])
        };

        var machine = await adminService.GetMachineAsync(machineId, CancellationToken.None);
        Assert(
            failures,
            "Admin machine view should count recoverable unsettled rounds as active work.",
            machine.ActiveRounds == 1);

        var blocked = false;
        try
        {
            await adminService.ResetMachineAsync(adminId, machineId, CancellationToken.None);
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("active rounds", StringComparison.Ordinal))
        {
            blocked = true;
        }

        Assert(
            failures,
            "Admin reset should reject completed-but-unsettled rounds because they are still recoverable player state.",
            blocked);
    }

    private static async Task AdminResetAllowsClosedSessionsWithoutActiveRoundsAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var adminService = new AdminService(store, new NoOpPersistentStateStore());
        var adminId = Guid.Parse("20000000-0000-0000-0000-000000000012");
        var userId = Guid.Parse("20000000-0000-0000-0000-000000000013");

        SeedPlayer(store, adminId, "reset-admin", 500_000m, role: "Admin");
        SeedPlayer(store, userId, "reset-credits", 2_000_000m);

        var machineId = store.Machines.Values.First(machine => machine.IsOpen).Id;
        var session = new MachineSessionState
        {
            UserId = userId,
            MachineId = machineId,
            MachineCredits = 40_000_000m,
            TotalCashIn = 1_000_000m,
            IsMachineClosed = true,
            CounterplayScore = 4,
            LastUpdatedUtc = DateTime.UtcNow
        };
        store.MachineSessions[session.SessionId] = session;
        store.MachineLedgers[machineId].CapitalIn = 900_000m;
        store.MachineLedgers[machineId].CapitalOut = 700_000m;

        var threw = false;
        try
        {
            await adminService.ResetMachineAsync(adminId, machineId, CancellationToken.None);
        }
        catch
        {
            threw = true;
        }

        Assert(
            failures,
            "Admin reset should not block solely because a closed machine session still has credits when no recoverable round exists.",
            !threw);
        Assert(
            failures,
            "Admin reset should clear closed-session credits, total cash-in, close state, and counterplay score.",
            session.MachineCredits == 0m && session.TotalCashIn == 0m && !session.IsMachineClosed && session.CounterplayScore == 0);
        Assert(
            failures,
            "Admin reset should still zero the machine ledger state.",
            store.MachineLedgers[machineId].CapitalIn == 0m && store.MachineLedgers[machineId].CapitalOut == 0m);
    }

    private static MachineSessionState GetSession(InMemoryDataStore store, Guid userId, int machineId)
        => store.MachineSessions.Values.First(session => session.UserId == userId && session.MachineId == machineId);

    private static FiveCardDrawState CreateState(RoundPhase phase, RoundState state, IReadOnlyList<string> cards, bool[]? held = null)
    {
        var hand = cards.Select(CleanRoomCard.FromCode).ToArray();
        return new FiveCardDrawState(
            SeedToken: 0UL,
            Deck: hand,
            Hand: hand,
            DrawIndex: hand.Length,
            Held: held ?? [false, false, false, false, false],
            Phase: phase,
            State: state);
    }

    private sealed class SignalingEntropyGenerator(ulong fixedSeed, ManualResetEventSlim seedRequested) : IEntropyGenerator
    {
        public ulong CreateSeed(Guid userId, int machineId, decimal betAmount, MachineLedgerState ledger)
        {
            seedRequested.Set();
            return fixedSeed;
        }
    }

    private static void SeedPlayer(InMemoryDataStore store, Guid userId, string username, decimal walletBalance, string role = "Player")
    {
        var user = new User
        {
            Id = userId,
            Username = username,
            PhoneNumber = $"+961{Math.Abs(username.GetHashCode()):0000000}",
            PasswordHash = "test-hash",
            IsOtpVerified = true,
            Role = role
        };

        store.Profiles[userId] = user;
        store.Users[userId] = user;
        store.MemberProfiles[userId] = new MemberProfile
        {
            UserId = userId,
            Username = username,
            DisplayName = username,
            Email = $"{username}@lucky5.local",
            PhoneNumber = user.PhoneNumber,
            WalletBalance = walletBalance,
            LastSeenUtc = DateTime.UtcNow
        };
    }

    private static void Assert(List<string> failures, string message, bool condition)
    {
        if (!condition)
        {
            failures.Add(message);
        }
    }
}
