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
namespace Lucky5.Application.Interfaces;

using Lucky5.Domain.Entities;
using Lucky5.Domain.Game.CleanRoom;

public interface IDataStore
{
    // User/Profile operations
    Task<User?> GetProfileAsync(Guid userId, CancellationToken cancellationToken);
    Task<User> CreateProfileAsync(User profile, CancellationToken cancellationToken);
    Task<User> UpdateProfileAsync(User profile, CancellationToken cancellationToken);
    Task<MemberProfile?> GetMemberProfileAsync(Guid userId, CancellationToken cancellationToken);
    Task<MemberProfile> UpdateMemberProfileAsync(MemberProfile profile, CancellationToken cancellationToken);

    // Machine operations
    Task<Machine?> GetMachineAsync(int machineId, CancellationToken cancellationToken);
    Task<IReadOnlyList<Machine>> GetMachinesAsync(CancellationToken cancellationToken);

    // Session operations
    Task<MachineSessionState?> GetMachineSessionAsync(Guid userId, int machineId, CancellationToken cancellationToken);
    Task<MachineSessionState> CreateMachineSessionAsync(MachineSessionState session, CancellationToken cancellationToken);
    Task<MachineSessionState> UpdateMachineSessionAsync(MachineSessionState session, CancellationToken cancellationToken);
    Task<IReadOnlyList<MachineSessionState>> GetMachineSessionsAsync(int machineId, CancellationToken cancellationToken);

    // Ledger operations
    Task<MachineLedgerState?> GetMachineLedgerAsync(int machineId, CancellationToken cancellationToken);
    Task<MachineLedgerState> UpdateMachineLedgerAsync(MachineLedgerState ledger, CancellationToken cancellationToken);

    // Round operations
    Task<GameRound?> GetRoundAsync(Guid roundId, CancellationToken cancellationToken);
    Task<GameRound> SaveRoundAsync(GameRound round, CancellationToken cancellationToken);
    Task<GameRound?> GetLatestRoundAsync(Guid userId, int machineId, CancellationToken cancellationToken);
    Task ClearActiveRoundsAsync(CancellationToken cancellationToken);

    // Wallet operations
    Task AddWalletLedgerEntryAsync(WalletLedgerEntry entry, CancellationToken cancellationToken);
    Task<IReadOnlyList<WalletLedgerEntry>> GetWalletLedgerAsync(Guid userId, CancellationToken cancellationToken);

    // Helper methods
    Task<User> RequireProfileAsync(Guid userId, CancellationToken cancellationToken);
    Task<Machine> RequireMachineAsync(int machineId, CancellationToken cancellationToken);
    Task<MachineSessionState> RequireMachineSessionAsync(Guid userId, int machineId, bool createIfMissing = true, CancellationToken cancellationToken = default);
    Task<MachineLedgerState> RequireMachineLedgerAsync(int machineId, CancellationToken cancellationToken);

    // Pre-seeding and cleanup
    Task PreSeedDataAsync(CancellationToken cancellationToken);
    Task ClearStaleRoundsAsync(TimeSpan maxAge, CancellationToken cancellationToken);
}
