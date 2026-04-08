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

    public async Task<PersistentStateSnapshot> CaptureAsync(CancellationToken cancellationToken)
    {
        // Capture all current state from the in-memory store
        var users = await dataStore.GetUsersAsync();
        var profiles = await dataStore.GetProfilesAsync();
        var machineSessions = await dataStore.GetMachineSessionsAsync();
        var machineLedgers = await dataStore.GetMachineLedgersAsync();
        var activeRounds = await dataStore.GetActiveRoundsAsync();
        var walletLedgerEntries = await dataStore.GetWalletLedgerEntriesAsync();

        return new PersistentStateSnapshot
        {
            Users = users.ToArray(),
            Profiles = profiles.ToArray(),
            MachineSessions = machineSessions.ToArray(),
            MachineLedgers = machineLedgers.ToArray(),
            ActiveRounds = activeRounds.ToArray(),
            WalletLedgerEntries = walletLedgerEntries.ToArray()
        };
    }

    public async Task RestoreAsync(PersistentStateSnapshot snapshot, CancellationToken cancellationToken)
    {
        // Restore all state to the in-memory store
        // Note: This is a simplified implementation - in a real scenario,
        // you'd need to handle conflicts and ensure atomic restoration
        
        foreach (var user in snapshot.Users)
        {
            await dataStore.SaveUserAsync(user);
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
