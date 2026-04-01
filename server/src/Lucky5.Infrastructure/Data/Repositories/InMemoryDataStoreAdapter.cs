namespace Lucky5.Infrastructure.Data.Repositories;

using Lucky5.Application.Interfaces;
using Lucky5.Domain.Entities;
using Lucky5.Domain.Game.CleanRoom;
using Lucky5.Infrastructure.Services;

public class InMemoryDataStoreAdapter(InMemoryDataStore store) : IDataStore
{
    // User/Profile operations
    public Task<User?> GetProfileAsync(Guid userId, CancellationToken cancellationToken)
        => Task.FromResult(store.Profiles.TryGetValue(userId, out var profile) ? profile : null);

    public Task<User> CreateProfileAsync(User profile, CancellationToken cancellationToken)
    {
        store.Profiles.TryAdd(profile.Id, profile);
        store.Users[profile.Id] = profile;
        return Task.FromResult(profile);
    }

    public Task<User> UpdateProfileAsync(User profile, CancellationToken cancellationToken)
    {
        store.Profiles[profile.Id] = profile;
        store.Users[profile.Id] = profile;
        return Task.FromResult(profile);
    }

    public Task<MemberProfile?> GetMemberProfileAsync(Guid userId, CancellationToken cancellationToken)
        => Task.FromResult(store.MemberProfiles.TryGetValue(userId, out var profile) ? profile : null);

    public Task<MemberProfile> UpdateMemberProfileAsync(MemberProfile profile, CancellationToken cancellationToken)
    {
        store.MemberProfiles[profile.UserId] = profile;
        return Task.FromResult(profile);
    }

    // Machine operations
    public Task<Machine?> GetMachineAsync(int machineId, CancellationToken cancellationToken)
        => Task.FromResult(store.Machines.TryGetValue(machineId, out var machine) ? machine : null);

    public Task<IReadOnlyList<Machine>> GetMachinesAsync(CancellationToken cancellationToken)
        => Task.FromResult<IReadOnlyList<Machine>>(store.Machines.Values.ToList());

    // Session operations
    public Task<MachineSessionState?> GetMachineSessionAsync(Guid userId, int machineId, CancellationToken cancellationToken)
    {
        var session = store.MachineSessions.Values.FirstOrDefault(s => s.UserId == userId && s.MachineId == machineId);
        return Task.FromResult(session);
    }

    public Task<MachineSessionState> CreateMachineSessionAsync(MachineSessionState session, CancellationToken cancellationToken)
    {
        store.MachineSessions.TryAdd(session.SessionId, session);
        return Task.FromResult(session);
    }

    public Task<MachineSessionState> UpdateMachineSessionAsync(MachineSessionState session, CancellationToken cancellationToken)
    {
        store.MachineSessions[session.SessionId] = session;
        return Task.FromResult(session);
    }

    public Task<IReadOnlyList<MachineSessionState>> GetMachineSessionsAsync(int machineId, CancellationToken cancellationToken)
    {
        var sessions = store.MachineSessions.Values.Where(s => s.MachineId == machineId).ToList();
        return Task.FromResult<IReadOnlyList<MachineSessionState>>(sessions);
    }

    // Ledger operations
    public Task<MachineLedgerState?> GetMachineLedgerAsync(int machineId, CancellationToken cancellationToken)
        => Task.FromResult(store.MachineLedgers.TryGetValue(machineId, out var ledger) ? ledger : null);

    public Task<MachineLedgerState> UpdateMachineLedgerAsync(MachineLedgerState ledger, CancellationToken cancellationToken)
    {
        store.MachineLedgers[ledger.MachineId] = ledger;
        return Task.FromResult(ledger);
    }

    // Round operations
    public Task<GameRound?> GetRoundAsync(Guid roundId, CancellationToken cancellationToken)
        => Task.FromResult(store.ActiveRounds.TryGetValue(roundId, out var round) ? round : null);

    public Task<GameRound> SaveRoundAsync(GameRound round, CancellationToken cancellationToken)
    {
        store.ActiveRounds[round.RoundId] = round;
        return Task.FromResult(round);
    }

    public Task<GameRound?> GetLatestRoundAsync(Guid userId, int machineId, CancellationToken cancellationToken)
    {
        var round = store.ActiveRounds.Values
            .Where(r => r.UserId == userId && r.MachineId == machineId)
            .OrderByDescending(r => r.CreatedUtc)
            .FirstOrDefault();
        return Task.FromResult(round);
    }

    public Task ClearActiveRoundsAsync(CancellationToken cancellationToken)
    {
        store.ActiveRounds.Clear();
        return Task.CompletedTask;
    }

    // Wallet operations
    public Task AddWalletLedgerEntryAsync(WalletLedgerEntry entry, CancellationToken cancellationToken)
    {
        store.Ledger.Add(entry);
        store.WalletLedger.Add(entry);
        return Task.CompletedTask;
    }

    public Task<IReadOnlyList<WalletLedgerEntry>> GetWalletLedgerAsync(Guid userId, CancellationToken cancellationToken)
    {
        var entries = store.WalletLedger.Where(e => e.UserId == userId).ToList();
        return Task.FromResult<IReadOnlyList<WalletLedgerEntry>>(entries);
    }

    // Helper methods
    public async Task<User> RequireProfileAsync(Guid userId, CancellationToken cancellationToken)
    {
        var profile = await GetProfileAsync(userId, cancellationToken);
        if (profile == null)
            throw new KeyNotFoundException($"Profile not found: {userId}");
        return profile;
    }

    public async Task<Machine> RequireMachineAsync(int machineId, CancellationToken cancellationToken)
    {
        var machine = await GetMachineAsync(machineId, cancellationToken);
        if (machine == null)
            throw new KeyNotFoundException($"Machine not found: {machineId}");
        return machine;
    }

    public async Task<MachineSessionState> RequireMachineSessionAsync(Guid userId, int machineId, bool createIfMissing = true, CancellationToken cancellationToken = default)
    {
        var session = await GetMachineSessionAsync(userId, machineId, cancellationToken);
        if (session == null && createIfMissing)
        {
            session = new MachineSessionState
            {
                UserId = userId,
                MachineId = machineId,
                MachineCredits = 0,
                CreatedUtc = DateTime.UtcNow,
                LastUpdatedUtc = DateTime.UtcNow
            };
            await CreateMachineSessionAsync(session, cancellationToken);
        }
        if (session == null)
            throw new KeyNotFoundException($"Session not found for user {userId} on machine {machineId}");
        return session;
    }

    public async Task<MachineLedgerState> RequireMachineLedgerAsync(int machineId, CancellationToken cancellationToken)
    {
        var ledger = await GetMachineLedgerAsync(machineId, cancellationToken);
        if (ledger == null)
            throw new KeyNotFoundException($"Ledger not found for machine {machineId}");
        return ledger;
    }

    // Pre-seeding and cleanup
    public Task PreSeedDataAsync(CancellationToken cancellationToken)
    {
        store.PreSeedData();
        return Task.CompletedTask;
    }

    public Task ClearStaleRoundsAsync(TimeSpan maxAge, CancellationToken cancellationToken)
    {
        store.ClearStaleRounds(maxAge);
        return Task.CompletedTask;
    }
}
