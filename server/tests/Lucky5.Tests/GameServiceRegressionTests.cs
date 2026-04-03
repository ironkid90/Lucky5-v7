namespace Lucky5.Tests;

using System.Threading;
using Lucky5.Application.Contracts;
using Lucky5.Application.Requests;
using Lucky5.Domain.Entities;
using Lucky5.Domain.Game.CleanRoom;
using Lucky5.Infrastructure.Services;

public static class GameServiceRegressionTests
{
    public static async Task RunAsync(List<string> failures)
    {
        await FourOfAKindSlotIsCapturedAtomicallyAtDealAsync(failures);
        await GetActiveRoundKeepsDrawnStateUntilPayoutSettledAsync(failures);
        await ClosedMachineSessionsCanCashOutAndResetAsync(failures);
        await CashOutIsIdempotentAfterDrainedClosedSessionAsync(failures);
        await MachineSessionCashOutEligibilityFollowsRulesAsync(failures);
        await CashOutRejectsBelowThresholdWhenMachineIsNotClosedAsync(failures);
        await AdminViewsAndResetRespectRecoverableRoundsAsync(failures);
        await AdminResetRejectsOutstandingMachineCreditsAsync(failures);
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
        var service = new GameService(store, new SignalingEntropyGenerator(fixedSeed, seedRequested), new NoOpPersistentStateStore());

        var userId = Guid.Parse("10000000-0000-0000-0000-000000000001");
        SeedPlayer(store, userId, "slot-race", 2_000_000m);

        var machineId = store.Machines.Values.First().Id;
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

        if (!store.ActiveRounds.TryGetValue(deal.RoundId, out var round))
        {
            failures.Add("Deal should register an active round for Four-of-a-Kind slot regression coverage.");
            return;
        }

        if (round.ActiveFourOfAKindSlotAtDeal != expectedSlot)
        {
            failures.Add($"Four-of-a-Kind slot should stay at the deal-time value {expectedSlot}, but was captured as {round.ActiveFourOfAKindSlotAtDeal} after a concurrent ledger mutation.");
        }
    }

    private static async Task GetActiveRoundKeepsDrawnStateUntilPayoutSettledAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var service = new GameService(store, new DefaultEntropyGenerator(), new NoOpPersistentStateStore());

        var userId = Guid.Parse("10000000-0000-0000-0000-000000000002");
        SeedPlayer(store, userId, "reconnect", 2_000_000m);

        var machineId = store.Machines.Values.First().Id;
        var seed = 0xBADC0FFEEUL;
        var opening = FiveCardDrawEngine.DealFiveCardDraw(seed);
        var drawn = FiveCardDrawEngine.Reduce(
            FiveCardDrawEngine.Reduce(
                opening,
                new RoundAction(RoundActionKind.SetHoldMask, HoldMask: [true, true, true, true, true])),
            new RoundAction(RoundActionKind.Draw));

        var round = new GameRound
        {
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
        if (active is null)
        {
            failures.Add("GetActiveRoundAsync should keep a drawn round available until the payout is settled.");
            return;
        }

        if (!string.Equals(active.Phase, "Drawn", StringComparison.Ordinal))
        {
            failures.Add($"Reconnect hydration should report a drawn round as phase 'Drawn', but returned '{active.Phase}'.");
        }

        if (active.PendingWinAmount != round.WinAmount)
        {
            failures.Add($"Reconnect hydration should preserve the pending win amount {round.WinAmount}, but returned {active.PendingWinAmount}.");
        }
    }

    private static async Task ClosedMachineSessionsCanCashOutAndResetAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var service = new GameService(store, new DefaultEntropyGenerator(), new NoOpPersistentStateStore());

        var userId = Guid.Parse("10000000-0000-0000-0000-000000000003");
        var adminId = Guid.Parse("10000000-0000-0000-0000-000000000004");
        SeedPlayer(store, userId, "closeout", 500_000m);
        SeedPlayer(store, adminId, "reset-admin", 500_000m, role: "Admin");

        var machineId = store.Machines.Values.First().Id;
        var session = new MachineSessionState
        {
            UserId = userId,
            MachineId = machineId,
            MachineCredits = 40_000_000m,
            TotalCashIn = 1_000_000m,
            IsMachineClosed = true,
            LastUpdatedUtc = DateTime.UtcNow
        };
        store.MachineSessions[session.SessionId] = session;

        var walletBeforeCashOut = store.MemberProfiles[userId].WalletBalance;
        var cashout = await service.CashOutAsync(userId, machineId, CancellationToken.None);

        if (cashout.MachineCredits != 0m)
        {
            failures.Add($"Cashing out a closed machine should drain machine credits to zero, but {cashout.MachineCredits} credits remained.");
        }

        if (cashout.IsMachineClosed)
        {
            failures.Add("Cashing out a closed machine should reopen the session for future play.");
        }

        if (cashout.WalletBalance != walletBeforeCashOut + 40_000_000m)
        {
            failures.Add("Cashing out a closed machine should return the closed machine balance to the member wallet.");
        }

        session.MachineCredits = 40_000_000m;
        session.TotalCashIn = 1_000_000m;
        session.IsMachineClosed = true;
        session.CounterplayScore = 3;
        store.MachineLedgers[machineId].CapitalIn = 900_000m;
        store.MachineLedgers[machineId].CapitalOut = 700_000m;

        await service.ResetMachineAsync(adminId, machineId, CancellationToken.None);

        if (session.IsMachineClosed || session.MachineCredits != 0m || session.TotalCashIn != 0m || session.CounterplayScore != 0)
        {
            failures.Add("ResetMachineAsync should clear closed-session state, machine credits, total cash-in, and counterplay score for the machine.");
        }

        if (store.MachineLedgers[machineId].CapitalIn != 0m || store.MachineLedgers[machineId].CapitalOut != 0m)
        {
            failures.Add("ResetMachineAsync should zero the machine ledger capital counters.");
        }
    }

    private static async Task CashOutIsIdempotentAfterDrainedClosedSessionAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var service = new GameService(store, new DefaultEntropyGenerator(), new NoOpPersistentStateStore());

        var userId = Guid.Parse("10000000-0000-0000-0000-000000000007");
        SeedPlayer(store, userId, "idempotent-cashout", 2_000_000m);

        var machineId = store.Machines.Values.First().Id;
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

        var first = await service.CashOutAsync(userId, machineId, CancellationToken.None);
        if (first.MachineCredits != 0m || first.IsMachineClosed)
        {
            failures.Add("First cash-out should fully drain machine credits and reopen the closed session.");
        }

        var threw = false;
        try
        {
            _ = await service.CashOutAsync(userId, machineId, CancellationToken.None);
        }
        catch (InvalidOperationException)
        {
            threw = true;
        }

        if (threw)
        {
            failures.Add("Repeated cash-out on an already drained closed session should be idempotent and not throw.");
        }
    }

    private static async Task MachineSessionCashOutEligibilityFollowsRulesAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var service = new GameService(store, new DefaultEntropyGenerator(), new NoOpPersistentStateStore());

        var userId = Guid.Parse("20000000-0000-0000-0000-000000000001");
        SeedPlayer(store, userId, "cashout-rules", 2_000_000m);

        var machineId = store.Machines.Values.First().Id;
        await service.CashInAsync(userId, machineId, 200_000m, CancellationToken.None);

        var sessionDto = await service.GetMachineSessionAsync(userId, machineId, CancellationToken.None);
        if (sessionDto.CanCashOut)
        {
            failures.Add("Machine session should not be cash-out eligible before reaching the 2x threshold or a machine-close event.");
        }

        var session = store.MachineSessions.Values.First(s => s.UserId == userId && s.MachineId == machineId);
        session.MachineCredits = 400_000m;
        session.LastUpdatedUtc = DateTime.UtcNow;

        sessionDto = await service.GetMachineSessionAsync(userId, machineId, CancellationToken.None);
        if (!sessionDto.CanCashOut)
        {
            failures.Add("Machine session should become cash-out eligible once credits reach the documented 2x threshold.");
        }

        session.MachineCredits = 250_000m;
        session.IsMachineClosed = true;
        session.LastUpdatedUtc = DateTime.UtcNow;

        sessionDto = await service.GetMachineSessionAsync(userId, machineId, CancellationToken.None);
        if (!sessionDto.CanCashOut)
        {
            failures.Add("Machine session should remain cash-out eligible after a machine-close event even if credits fall below the 2x threshold.");
        }
    }

    private static async Task CashOutRejectsBelowThresholdWhenMachineIsNotClosedAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var service = new GameService(store, new DefaultEntropyGenerator(), new NoOpPersistentStateStore());

        var userId = Guid.Parse("20000000-0000-0000-0000-000000000002");
        SeedPlayer(store, userId, "cashout-blocked", 2_000_000m);

        var machineId = store.Machines.Values.First().Id;
        await service.CashInAsync(userId, machineId, 200_000m, CancellationToken.None);

        var blocked = false;
        try
        {
            await service.CashOutAsync(userId, machineId, CancellationToken.None);
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("Cash out is only available", StringComparison.Ordinal))
        {
            blocked = true;
        }

        if (!blocked)
        {
            failures.Add("CashOutAsync should reject sessions that are below the 2x threshold and not machine-closed.");
        }
    }

    private static async Task AdminViewsAndResetRespectRecoverableRoundsAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var adminService = new AdminService(store, new NoOpPersistentStateStore());

        var adminId = Guid.Parse("20000000-0000-0000-0000-000000000003");
        var userId = Guid.Parse("20000000-0000-0000-0000-000000000004");
        var machineId = store.Machines.Values.First().Id;

        SeedPlayer(store, adminId, "recover-admin", 500_000m, role: "Admin");
        SeedPlayer(store, userId, "recoverable-round", 2_000_000m);

        store.ActiveRounds[Guid.Parse("30000000-0000-0000-0000-000000000002")] = new GameRound
        {
            RoundId = Guid.Parse("30000000-0000-0000-0000-000000000002"),
            UserId = userId,
            MachineId = machineId,
            BetAmount = 5_000m,
            HandRank = "FullHouse",
            WinAmount = 60_000m,
            OriginalWinAmount = 60_000m,
            IsCompleted = true,
            IsPayoutSettled = false,
            CleanRoomState = CreateState(
                RoundPhase.Drawn,
                RoundState.Evaluate,
                ["AH", "AD", "AC", "KH", "KD"])
        };

        var machine = await adminService.GetMachineAsync(machineId, CancellationToken.None);
        if (machine.ActiveRounds != 1)
        {
            failures.Add($"Admin machine view should count recoverable unsettled rounds as active work, but reported {machine.ActiveRounds}.");
        }

        var blocked = false;
        try
        {
            await adminService.ResetMachineAsync(adminId, machineId, CancellationToken.None);
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("active rounds", StringComparison.Ordinal))
        {
            blocked = true;
        }

        if (!blocked)
        {
            failures.Add("Admin reset should reject completed-but-unsettled rounds because they are still recoverable player state.");
        }
    }

    private static async Task AdminResetRejectsOutstandingMachineCreditsAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var service = new GameService(store, new DefaultEntropyGenerator(), new NoOpPersistentStateStore());
        var adminService = new AdminService(store, new NoOpPersistentStateStore());

        var adminId = Guid.Parse("20000000-0000-0000-0000-000000000005");
        var userId = Guid.Parse("20000000-0000-0000-0000-000000000006");
        var machineId = store.Machines.Values.First().Id;

        SeedPlayer(store, adminId, "reset-admin", 500_000m, role: "Admin");
        SeedPlayer(store, userId, "reset-credits", 2_000_000m);

        await service.CashInAsync(userId, machineId, 200_000m, CancellationToken.None);

        var blocked = false;
        try
        {
            await adminService.ResetMachineAsync(adminId, machineId, CancellationToken.None);
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("player credits", StringComparison.Ordinal))
        {
            blocked = true;
        }

        if (!blocked)
        {
            failures.Add("Admin reset should reject machines that still hold player credits instead of silently bypassing or destroying session state.");
        }
    }

    private static FiveCardDrawState CreateState(RoundPhase phase, RoundState state, IReadOnlyList<string> cards)
    {
        var hand = cards.Select(CleanRoomCard.FromCode).ToArray();
        return new FiveCardDrawState(
            SeedToken: 0UL,
            Deck: hand,
            Hand: hand,
            DrawIndex: hand.Length,
            Held: [false, false, false, false, false],
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
}
