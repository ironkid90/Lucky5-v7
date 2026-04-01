namespace Lucky5.Tests;

using System.Threading;
using Lucky5.Application.Contracts;
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
        var service = new GameService(new InMemoryDataStoreAdapter(store), new SignalingEntropyGenerator(fixedSeed, seedRequested));

        var userId = Guid.Parse("10000000-0000-0000-0000-000000000001");
        store.Profiles[userId] = new MemberProfile
        {
            UserId = userId,
            Username = "slot-race",
            WalletBalance = 2_000_000m,
            LastSeenUtc = DateTime.UtcNow
        };

        var machineId = store.Machines.First().Id;
        var minBet = store.Machines.First(m => m.Id == machineId).MinBet;
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

    private static async Task MachineSessionCashOutEligibilityFollowsRulesAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var service = new GameService(new InMemoryDataStoreAdapter(store), new DefaultEntropyGenerator());
        var userId = Guid.Parse("20000000-0000-0000-0000-000000000001");
        store.Profiles[userId] = new MemberProfile
        {
            UserId = userId,
            Username = "cashout-rules",
            WalletBalance = 2_000_000m,
            LastSeenUtc = DateTime.UtcNow
        };

        var machineId = store.Machines.First().Id;
        await service.CashInAsync(userId, machineId, 200_000m, CancellationToken.None);

        var sessionDto = await service.GetMachineSessionAsync(userId, machineId, CancellationToken.None);
        if (sessionDto.CanCashOut)
        {
            failures.Add("Machine session should not be cash-out eligible before reaching the 2x threshold or a machine-close event.");
        }

        var session = store.MachineSessions[$"{userId:N}:{machineId}"];
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
        var service = new GameService(new InMemoryDataStoreAdapter(store), new DefaultEntropyGenerator());
        var userId = Guid.Parse("20000000-0000-0000-0000-000000000002");
        store.Profiles[userId] = new MemberProfile
        {
            UserId = userId,
            Username = "cashout-blocked",
            WalletBalance = 2_000_000m,
            LastSeenUtc = DateTime.UtcNow
        };

        var machineId = store.Machines.First().Id;
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

    private static async Task CompletedButUnsettledRoundRemainsRecoverableAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var service = new GameService(new InMemoryDataStoreAdapter(store), new DefaultEntropyGenerator());
        var userId = Guid.Parse("20000000-0000-0000-0000-000000000003");
        var machineId = store.Machines.First().Id;

        store.ActiveRounds[Guid.Parse("30000000-0000-0000-0000-000000000001")] = new GameRound
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

        var round = await service.GetActiveRoundAsync(userId, machineId, CancellationToken.None);
        if (round is null)
        {
            failures.Add("GetActiveRoundAsync should return completed-but-unsettled winning rounds so refresh/reconnect can restore them.");
            return;
        }

        if (!string.Equals(round.Phase, "Drawn", StringComparison.Ordinal))
        {
            failures.Add($"Recoverable winning rounds should hydrate as Drawn, but the API returned '{round.Phase}'.");
        }
    }

    private static async Task AdminViewsAndResetRespectRecoverableRoundsAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var adminService = new AdminService(store);
        var adminId = Guid.Parse("00000000-0000-0000-0000-000000000001");
        var userId = Guid.Parse("20000000-0000-0000-0000-000000000004");
        var machineId = store.Machines.First().Id;

        store.Profiles[userId] = new MemberProfile
        {
            UserId = userId,
            Username = "recoverable-round",
            WalletBalance = 2_000_000m,
            LastSeenUtc = DateTime.UtcNow
        };

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
        var service = new GameService(new InMemoryDataStoreAdapter(store), new DefaultEntropyGenerator());
        var adminService = new AdminService(store);
        var adminId = Guid.Parse("00000000-0000-0000-0000-000000000001");
        var userId = Guid.Parse("20000000-0000-0000-0000-000000000005");
        var machineId = store.Machines.First().Id;

        store.Profiles[userId] = new MemberProfile
        {
            UserId = userId,
            Username = "reset-credits",
            WalletBalance = 2_000_000m,
            LastSeenUtc = DateTime.UtcNow
        };

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
}
