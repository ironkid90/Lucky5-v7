namespace Lucky5.Tests;

using Lucky5.Domain.Entities;
using Lucky5.Domain.Game.CleanRoom;
using Lucky5.Infrastructure.Persistence;
using Lucky5.Infrastructure.Services;

public static class PersistentStateRecoveryTests
{
    public static async Task RunAsync(List<string> failures)
    {
        await RestoreReplacesSeededStateAndKeepsLegacyCollectionsInSyncAsync(failures);
        await CaptureOrdersStateDeterministicallyAndClonesMutableEntitiesAsync(failures);
    }

    private static async Task RestoreReplacesSeededStateAndKeepsLegacyCollectionsInSyncAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var coordinator = new InMemoryPersistentStateCoordinator(store);
        var userId = Guid.Parse("41000000-0000-0000-0000-000000000001");
        var sessionId = Guid.Parse("42000000-0000-0000-0000-000000000001");
        var roundId = Guid.Parse("43000000-0000-0000-0000-000000000001");

        var snapshot = new PersistentStateSnapshot
        {
            Machines = [new Machine { Id = 9, GameId = 1, Name = "Durable Test", MachineSerial = "209009", MachineSerie = "31", MachineKent = "9", IsOpen = true, MinBet = 5_000, MaxBet = 10_000 }],
            Users = [new User { Id = userId, Username = "durable-player", Role = "player", IsOtpVerified = true }],
            Profiles = [new MemberProfile { UserId = userId, Username = "durable-player", WalletBalance = 123_456m, Credit = 10_000m }],
            MachineSessions = [new MachineSessionState { SessionId = sessionId, UserId = userId, MachineId = 9, MachineCredits = 40_000_000m, TotalCashIn = 1_000_000m, IsMachineClosed = false }],
            MachineLedgers = [new MachineLedgerState { MachineId = 9, CapitalIn = 900_000m, CapitalOut = 300_000m, TargetRtp = 0m, LastPayoutScale = 0m, ActiveFourOfAKindSlot = 5 }],
            ActiveRounds = [new GameRound { RoundId = roundId, UserId = userId, MachineId = 9, BetAmount = 5_000m, IsCompleted = false, CleanRoomState = FiveCardDrawState.Create(11UL, FiveCardDrawEngine.ParseCards(["AS", "KD", "QH", "JC", "10S"]), FiveCardDrawEngine.ParseCards(["AS", "KD", "QH", "JC", "10S"])) }],
            WalletLedgerEntries = [new WalletLedgerEntry { UserId = userId, Amount = -5_000m, BalanceAfter = 123_456m, TransactionType = "Bet", ReferenceId = roundId.ToString("N") }]
        };

        await coordinator.RestoreAsync(snapshot, CancellationToken.None);

        Assert(failures, "Restore should replace seeded users with durable users", store.Users.Count == 1 && store.Users.ContainsKey(userId));
        Assert(failures, "Restore should keep concurrent profile mirror synced", store.Profiles.Count == 1 && store.Profiles.ContainsKey(userId));
        Assert(failures, "Restore should keep legacy session key synced", store.MachineSessionStates.ContainsKey($"{userId:N}:9"));
        Assert(failures, "Restore should keep wallet ledger mirrors synced", store.Ledger.Count == 1 && store.WalletLedger.Count == 1);
        Assert(failures, "Restore should normalize machine-close status from recovered credits", store.MachineSessions[sessionId].IsMachineClosed);
        Assert(failures, "Restore should normalize ledger defaults deterministically", store.MachineLedgers[9].TargetRtp == EngineConfig.Default.TargetRtp && store.MachineLedgers[9].LastPayoutScale == EngineConfig.Default.DefaultPayoutScale && store.MachineLedgers[9].ActiveFourOfAKindSlot == 0);
        Assert(failures, "Restore should preserve active round for reconnect recovery", store.ActiveRounds.ContainsKey(roundId));
    }

    private static async Task CaptureOrdersStateDeterministicallyAndClonesMutableEntitiesAsync(List<string> failures)
    {
        var store = new InMemoryDataStore();
        var coordinator = new InMemoryPersistentStateCoordinator(store);
        var first = Guid.Parse("51000000-0000-0000-0000-000000000001");
        var second = Guid.Parse("51000000-0000-0000-0000-000000000002");

        store.Users.Clear();
        store.Profiles.Clear();
        store.MemberProfiles.Clear();
        store.Users[second] = new User { Id = second, Username = "z-user" };
        store.Users[first] = new User { Id = first, Username = "a-user" };
        store.MemberProfiles[second] = new MemberProfile { UserId = second, Username = "z-user", WalletBalance = 2m };
        store.MemberProfiles[first] = new MemberProfile { UserId = first, Username = "a-user", WalletBalance = 1m };

        var snapshot = await coordinator.CaptureAsync(CancellationToken.None);
        store.MemberProfiles[first].WalletBalance = 999m;

        Assert(failures, "Capture should order users by id for deterministic checkpoint bytes", snapshot.Users.Select(user => user.Id).SequenceEqual([first, second]));
        Assert(failures, "Capture should clone mutable profiles so later runtime mutations cannot alter an in-flight snapshot", snapshot.Profiles.First(profile => profile.UserId == first).WalletBalance == 1m);
        Assert(failures, "Capture should include seeded machine definitions for recovery", snapshot.Machines.Count >= 3);
    }

    private static void Assert(List<string> failures, string description, bool condition)
    {
        if (!condition)
        {
            failures.Add($"PersistentStateRecoveryTests: {description}");
        }
    }
}