using Lucky5.Application.Interfaces;
using Lucky5.Domain.Entities;
using Lucky5.Domain.Game.CleanRoom;

namespace Lucky5.Infrastructure.Persistence;

/// <summary>
/// In-memory implementation of IPersistentStateCoordinator that captures and restores state
/// from the current IDataStore. This bridges the gap between the existing in-memory store
/// and the new persistence layer.
/// </summary>
public sealed class InMemoryPersistentStateCoordinator : IPersistentStateCoordinator
{
    private readonly IDataStore dataStore;
    private readonly Lucky5.Infrastructure.Services.InMemoryDataStore inMemoryStore;

    public InMemoryPersistentStateCoordinator(IDataStore dataStore, Lucky5.Infrastructure.Services.InMemoryDataStore inMemoryStore)
    {
        this.dataStore = dataStore;
        this.inMemoryStore = inMemoryStore;
    }

    public Task<PersistentStateSnapshot> CaptureAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        var snapshot = new PersistentStateSnapshot
        {
            Users = inMemoryStore.Users.Values.ToArray(),
            Profiles = inMemoryStore.MemberProfiles.Values.ToArray(),
            MachineSessions = inMemoryStore.MachineSessions.Values.ToArray(),
            MachineLedgers = inMemoryStore.MachineLedgers.Values.ToArray(),
            ActiveRounds = inMemoryStore.ActiveRounds.Values.ToArray(),
            WalletLedgerEntries = inMemoryStore.Ledger.ToArray()
        };

        return Task.FromResult(snapshot);
    }

    public async Task RestoreAsync(PersistentStateSnapshot snapshot, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        // Replace current in-memory authoritative state with the durable snapshot.
        inMemoryStore.Users.Clear();
        inMemoryStore.MemberProfiles.Clear();
        inMemoryStore.MachineSessions.Clear();
        inMemoryStore.MachineLedgers.Clear();
        inMemoryStore.ActiveRounds.Clear();

        while (inMemoryStore.Ledger.TryTake(out _))
        {
        }

        foreach (var user in snapshot.Users)
        {
            cancellationToken.ThrowIfCancellationRequested();
            await dataStore.UpdateUserAsync(user);
        }

        foreach (var profile in snapshot.Profiles)
        {
            cancellationToken.ThrowIfCancellationRequested();
            await dataStore.UpdateProfileAsync(profile);
        }

        foreach (var session in snapshot.MachineSessions)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var normalizedSession = session;
            if (normalizedSession.MachineCredits <= 0m)
            {
                normalizedSession.TotalCashIn = 0m;
            }

            normalizedSession.IsMachineClosed = normalizedSession.MachineCredits >= EngineConfig.Default.CloseThreshold;

            await dataStore.UpdateMachineSessionAsync(normalizedSession);
        }

        foreach (var ledger in snapshot.MachineLedgers)
        {
            cancellationToken.ThrowIfCancellationRequested();
            await dataStore.UpdateMachineLedgerAsync(ledger);
        }

        foreach (var round in snapshot.ActiveRounds)
        {
            cancellationToken.ThrowIfCancellationRequested();
            await dataStore.SaveRoundAsync(round);
        }

        foreach (var entry in snapshot.WalletLedgerEntries)
        {
            cancellationToken.ThrowIfCancellationRequested();
            await dataStore.AddWalletLedgerEntryAsync(entry);
        }
    }
}
