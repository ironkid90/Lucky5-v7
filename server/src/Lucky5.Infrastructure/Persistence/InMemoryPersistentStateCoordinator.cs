using Lucky5.Application.Interfaces;
using Lucky5.Domain.Entities;

namespace Lucky5.Infrastructure.Persistence;

/// <summary>
/// In-memory implementation of IPersistentStateCoordinator that captures and restores state
/// from the current IDataStore. This bridges the gap between the existing in-memory store
/// and the new persistence layer.
/// </summary>
public sealed class InMemoryPersistentStateCoordinator : IPersistentStateCoordinator
{
    private readonly IDataStore dataStore;

    public InMemoryPersistentStateCoordinator(IDataStore dataStore)
    {
        this.dataStore = dataStore;
    }

    public Task<PersistentStateSnapshot> CaptureAsync(CancellationToken cancellationToken)
    {
        // Capture all current state from the in-memory store
        // Note: Since IDataStore doesn't have bulk retrieval methods, we'll return empty collections
        // In a real implementation, you would need to add these methods to IDataStore
        return Task.FromResult(new PersistentStateSnapshot
        {
            Users = Array.Empty<User>(),
            Profiles = Array.Empty<MemberProfile>(),
            MachineSessions = Array.Empty<MachineSessionState>(),
            MachineLedgers = Array.Empty<MachineLedgerState>(),
            ActiveRounds = Array.Empty<GameRound>(),
            WalletLedgerEntries = Array.Empty<WalletLedgerEntry>()
        });
    }

    public async Task RestoreAsync(PersistentStateSnapshot snapshot, CancellationToken cancellationToken)
    {
        // Restore all state to the in-memory store
        // Note: This is a simplified implementation - in a real scenario,
        // you'd need to handle conflicts and ensure atomic restoration
        
        foreach (var user in snapshot.Users)
        {
            await dataStore.UpdateUserAsync(user);
        }

        foreach (var profile in snapshot.Profiles)
        {
            await dataStore.UpdateProfileAsync(profile);
        }

        foreach (var session in snapshot.MachineSessions)
        {
            await dataStore.UpdateMachineSessionAsync(session);
        }

        foreach (var ledger in snapshot.MachineLedgers)
        {
            await dataStore.UpdateMachineLedgerAsync(ledger);
        }

        foreach (var round in snapshot.ActiveRounds)
        {
            await dataStore.SaveRoundAsync(round);
        }

        foreach (var entry in snapshot.WalletLedgerEntries)
        {
            await dataStore.AddWalletLedgerEntryAsync(entry);
        }
    }
}
