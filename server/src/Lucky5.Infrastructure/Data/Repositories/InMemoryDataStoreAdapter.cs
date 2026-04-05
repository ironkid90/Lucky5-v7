using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Lucky5.Domain.Entities;
using Lucky5.Application.Interfaces;
using Lucky5.Infrastructure.Services;

namespace Lucky5.Infrastructure.Data.Repositories;

/// <summary>
/// Adapter to make the existing InMemoryDataStore implement the new IDataStore interface,
/// allowing the application to run without a real database configured.
/// </summary>
public class InMemoryDataStoreAdapter : IDataStore
{
    private readonly InMemoryDataStore _store;

    public InMemoryDataStoreAdapter(InMemoryDataStore store)
    {
        _store = store ?? throw new ArgumentNullException(nameof(store));
    }

    public Task<User?> GetUserByUsernameAsync(string username)
    {
        var user = _store.Users.Values.FirstOrDefault(u => 
            u.Username.Equals(username, StringComparison.OrdinalIgnoreCase));
        return Task.FromResult(user);
    }

    public Task<User?> GetUserByIdAsync(Guid userId)
    {
        _store.Users.TryGetValue(userId, out var user);
        return Task.FromResult(user);
    }

    public Task UpdateUserAsync(User user)
    {
        _store.Users[user.Id] = user;
        return Task.CompletedTask;
    }

    public Task<MemberProfile?> GetProfileAsync(Guid userId)
    {
        _store.MemberProfiles.TryGetValue(userId, out var profile);
        return Task.FromResult(profile);
    }

    public Task UpdateProfileAsync(MemberProfile profile)
    {
        _store.MemberProfiles[profile.UserId] = profile;
        return Task.CompletedTask;
    }

    public Task<List<Machine>> GetMachinesAsync()
    {
        return Task.FromResult(_store.Machines.Values.ToList());
    }

    public Task<Machine?> GetMachineAsync(int machineId)
    {
        var machine = _store.Machines.Values.FirstOrDefault(m => m.Id == machineId);
        return Task.FromResult(machine);
    }

    public Task<List<Offer>> GetOffersAsync()
    {
        return Task.FromResult(_store.Offers.ToList());
    }

    public Task<MachineSessionState?> GetMachineSessionAsync(Guid userId, int machineId)
    {
        var session = _store.MachineSessions.Values
            .FirstOrDefault(s => s.UserId == userId && s.MachineId == machineId);
        return Task.FromResult(session);
    }

    public Task<MachineSessionState?> GetMachineSessionByIdAsync(Guid sessionId)
    {
        var session = _store.MachineSessions.Values
            .FirstOrDefault(s => s.SessionId == sessionId);
        return Task.FromResult(session);
    }

    public Task CreateMachineSessionAsync(MachineSessionState session)
    {
        _store.MachineSessions[session.SessionId] = session;
        return Task.CompletedTask;
    }

    public Task UpdateMachineSessionAsync(MachineSessionState session)
    {
        session.LastUpdatedUtc = DateTime.UtcNow;
        _store.MachineSessions[session.SessionId] = session;
        return Task.CompletedTask;
    }

    public Task DeleteMachineSessionAsync(Guid sessionId)
    {
        _store.MachineSessions.TryRemove(sessionId, out _);
        return Task.CompletedTask;
    }

    public Task<MachineLedgerState> GetOrInitializeMachineLedgerAsync(int machineId)
    {
        if (!_store.MachineLedgers.TryGetValue(machineId, out var ledger))
        {
            ledger = new MachineLedgerState { MachineId = machineId };
            _store.MachineLedgers[machineId] = ledger;
        }
        return Task.FromResult(ledger);
    }

    public Task UpdateMachineLedgerAsync(MachineLedgerState ledger)
    {
        _store.MachineLedgers[ledger.MachineId] = ledger;
        return Task.CompletedTask;
    }

    public Task<GameRound?> GetLatestRoundAsync(Guid userId, int machineId)
    {
        var round = _store.ActiveRounds.Values
            .Where(r => r.UserId == userId && r.MachineId == machineId)
            .OrderByDescending(r => r.CreatedUtc)
            .FirstOrDefault();
        return Task.FromResult(round);
    }

    public Task<GameRound?> GetRoundAsync(Guid roundId)
    {
        _store.ActiveRounds.TryGetValue(roundId, out var round);
        return Task.FromResult(round);
    }

    public Task SaveRoundAsync(GameRound round)
    {
        _store.ActiveRounds[round.RoundId] = round;
        return Task.CompletedTask;
    }

    public Task AddWalletLedgerEntryAsync(WalletLedgerEntry entry)
    {
        lock (_store.LedgerSync)
        {
            _store.Ledger.Add(entry);
        }
        return Task.CompletedTask;
    }
}
