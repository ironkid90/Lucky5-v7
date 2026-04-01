using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Lucky5.Domain.Entities;

namespace Lucky5.Application.Interfaces;

public interface IDataStore
{
    Task<User?> GetUserByUsernameAsync(string username);
    Task<User?> GetUserByIdAsync(Guid userId);
    Task UpdateUserAsync(User user);
    Task<MemberProfile?> GetProfileAsync(Guid userId);
    Task UpdateProfileAsync(MemberProfile profile);

    Task<List<Machine>> GetMachinesAsync();
    Task<Machine?> GetMachineAsync(int machineId);
    Task<List<Offer>> GetOffersAsync();

    Task<MachineSessionState?> GetMachineSessionAsync(Guid userId, int machineId);
    Task<MachineSessionState?> GetMachineSessionByIdAsync(Guid sessionId);
    Task CreateMachineSessionAsync(MachineSessionState session);
    Task UpdateMachineSessionAsync(MachineSessionState session);
    Task DeleteMachineSessionAsync(Guid sessionId);

    Task<MachineLedgerState> GetOrInitializeMachineLedgerAsync(int machineId);
    Task UpdateMachineLedgerAsync(MachineLedgerState ledger);

    Task<GameRound?> GetLatestRoundAsync(Guid userId, int machineId);
    Task<GameRound?> GetRoundAsync(Guid roundId);
    Task SaveRoundAsync(GameRound round);

    Task AddWalletLedgerEntryAsync(WalletLedgerEntry entry);
}
