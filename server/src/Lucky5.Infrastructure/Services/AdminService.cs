namespace Lucky5.Infrastructure.Services;

using System.Text;
using Lucky5.Application.Contracts;
using Lucky5.Application.Dtos;
using Lucky5.Application.Requests;
using Lucky5.Domain.Entities;
using Lucky5.Domain.Game.CleanRoom;
using Lucky5.Infrastructure.Persistence;
using PersistenceCoordinator = Lucky5.Infrastructure.Persistence.IPersistentStateCoordinator;
using PersistenceStore = Lucky5.Infrastructure.Persistence.IPersistentStateStore;

public sealed class AdminService(InMemoryDataStore store, PersistenceStore persistentStateStore, PersistenceCoordinator persistentStateCoordinator) : IAdminService
{
    public Task<IReadOnlyList<AdminUserDto>> ListUsersAsync(CancellationToken cancellationToken)
    {
        var users = store.Users.Values
            .OrderBy(user => user.Username, StringComparer.OrdinalIgnoreCase)
            .Select(ToAdminUserDto)
            .ToArray();
        return Task.FromResult<IReadOnlyList<AdminUserDto>>(users);
    }

    public Task<IReadOnlyList<AdminUserDto>> SearchUsersAsync(string query, CancellationToken cancellationToken)
    {
        var q = query.Trim();
        var users = store.Users.Values
            .Where(user => user.Username.Contains(q, StringComparison.OrdinalIgnoreCase)
                || (store.MemberProfiles.TryGetValue(user.Id, out var p) && (
                    p.DisplayName.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                    p.PhoneNumber.Contains(q, StringComparison.OrdinalIgnoreCase))))
            .OrderBy(user => user.Username, StringComparer.OrdinalIgnoreCase)
            .Select(ToAdminUserDto)
            .ToArray();
        return Task.FromResult<IReadOnlyList<AdminUserDto>>(users);
    }

    public Task<AdminUserDto> GetUserAsync(Guid userId, CancellationToken cancellationToken)
    {
        if (!store.Users.TryGetValue(userId, out var user))
            throw new KeyNotFoundException("User not found");
        return Task.FromResult(ToAdminUserDto(user));
    }

    public Task<WalletLedgerEntryDto> AdminCreditAsync(Guid adminId, AdminCreditRequest request, CancellationToken cancellationToken)
    {
        if (!store.MemberProfiles.TryGetValue(request.TargetUserId, out var profile))
            throw new KeyNotFoundException("Target user not found");
        if (request.Amount == 0) throw new InvalidOperationException("Amount must be non-zero");
        if (string.IsNullOrWhiteSpace(request.Reason)) throw new InvalidOperationException("Reason is required");
        if (profile.WalletBalance + request.Amount < 0) throw new InvalidOperationException("Insufficient wallet balance for debit");

        profile.WalletBalance += request.Amount;
        var row = new WalletLedgerEntry
        {
            UserId = request.TargetUserId,
            Amount = request.Amount,
            Type = request.Amount > 0 ? "AdminCredit" : "AdminDebit",
            Reference = $"admin:{adminId:N}:{Slug(request.Reason)}",
            BalanceAfter = profile.WalletBalance,
            CreatedUtc = DateTime.UtcNow
        };
        store.Ledger.Add(row);
        PersistStateSafe(cancellationToken);
        return Task.FromResult(new WalletLedgerEntryDto(row.Id, row.Amount, row.BalanceAfter, row.Type, row.Reference, row.CreatedUtc));
    }

    public Task<IReadOnlyList<AdminMachineDto>> ListMachinesAsync(CancellationToken cancellationToken)
    {
        var machines = store.Machines.Values.OrderBy(machine => machine.Id).Select(ToAdminMachineDto).ToArray();
        return Task.FromResult<IReadOnlyList<AdminMachineDto>>(machines);
    }

    public Task<AdminMachineDto> GetMachineAsync(int machineId, CancellationToken cancellationToken)
    {
        var machine = store.Machines.Values.FirstOrDefault(m => m.Id == machineId) ?? throw new KeyNotFoundException("Machine not found");
        return Task.FromResult(ToAdminMachineDto(machine));
    }

    public Task<AdminMachineDto> ResetMachineAsync(Guid adminId, int machineId, CancellationToken cancellationToken)
    {
        var machine = store.Machines.Values.FirstOrDefault(m => m.Id == machineId) ?? throw new KeyNotFoundException("Machine not found");
        if (store.ActiveRounds.Values.Any(r => r.MachineId == machineId && IsRoundRecoverable(r)))
            throw new InvalidOperationException("Cannot reset machine with active rounds");
        if (!store.MachineLedgers.TryGetValue(machineId, out var ledger))
            throw new KeyNotFoundException("Machine ledger not found");

        lock (store.LedgerSync)
        {
            var cfg = EngineConfig.Default;
            ledger.CapitalIn = 0;
            ledger.CapitalOut = 0;
            ledger.BaseCapitalOut = 0;
            ledger.JackpotCapitalOut = 0;
            ledger.DoubleUpCapitalOut = 0;
            ledger.RoundCount = 0;
            ledger.TargetRtp = cfg.TargetRtp;
            ledger.LastDistributionMode = DistributionMode.Neutral;
            ledger.LastRoundUtc = DateTime.UtcNow;
            ledger.LastPayoutScale = cfg.DefaultPayoutScale;
            ledger.ConsecutiveLosses = 0;
            ledger.RoundsSinceMediumWin = 0;
            ledger.CooldownRoundsRemaining = 0;
            ledger.NetSinceLastClose = 0;
            ledger.LastCloseRoundNumber = 0;
            ledger.LastWinChannel = WinChannel.None;
            ledger.RoundsSinceLucky5Hit = 0;
            ledger.JackpotFullHouse = cfg.JackpotFullHouseStart;
            ledger.JackpotFullHouseRank = 14;
            ledger.JackpotFourOfAKindA = cfg.JackpotFourOfAKindStart;
            ledger.JackpotFourOfAKindB = cfg.JackpotFourOfAKindStart;
            ledger.ActiveFourOfAKindSlot = 0;
            ledger.JackpotStraightFlush = cfg.JackpotStraightFlushStart;
            ledger.JackpotKent = cfg.JackpotKentStart;

            foreach (var session in store.MachineSessions.Values.Where(s => s.MachineId == machineId))
            {
                session.MachineCredits = 0m;
                session.TotalCashIn = 0m;
                session.IsMachineClosed = false;
                session.CounterplayScore = 0;
                session.LastUpdatedUtc = DateTime.UtcNow;
            }
        }

        store.Ledger.Add(new WalletLedgerEntry
        {
            UserId = adminId,
            Amount = 0,
            Type = "AdminMachineReset",
            Reference = $"machine:{machineId}:reset",
            BalanceAfter = store.MemberProfiles.TryGetValue(adminId, out var p) ? p.WalletBalance : 0,
            CreatedUtc = DateTime.UtcNow
        });

        PersistStateSafe(cancellationToken);
        return Task.FromResult(ToAdminMachineDto(machine));
    }

    public Task<DoorState> SetDoorStateAsync(int machineId, DoorState doorState, CancellationToken cancellationToken)
    {
        if (!store.MachineLedgers.TryGetValue(machineId, out var ledger))
            throw new KeyNotFoundException("Machine ledger not found");

        lock (store.LedgerSync)
        {
            ledger.DoorState = doorState;
        }

        PersistStateSafe(cancellationToken);
        return Task.FromResult(doorState);
    }

    public async Task<WalletLedgerEntryDto> RechargeBonusAsync(Guid userId, decimal rechargeAmount, CancellationToken cancellationToken)
    {
        if (!store.MemberProfiles.TryGetValue(userId, out var profile))
            throw new KeyNotFoundException("Profile not found");

        // Tiered bonus structure based on recharge amount
        decimal bonusPercentage = rechargeAmount switch
        {
            >= 10_000_000 => 0.20m, // 20% bonus for 10M+
            >= 5_000_000 => 0.15m,  // 15% bonus for 5M+
            >= 1_000_000 => 0.10m,  // 10% bonus for 1M+
            >= 500_000 => 0.05m,    // 5% bonus for 500K+
            _ => 0m                 // No bonus for smaller amounts
        };

        var bonusAmount = rechargeAmount * bonusPercentage;
        var totalAmount = rechargeAmount + bonusAmount;

        profile.WalletBalance += totalAmount;
        profile.BonusRechargeCount++;
        profile.BonusDate = DateTime.UtcNow;

        var row = new WalletLedgerEntry
        {
            UserId = userId,
            Amount = totalAmount,
            Type = "RechargeBonus",
            Reference = $"Recharge: {rechargeAmount:N0}, Bonus: {bonusAmount:N0}",
            BalanceAfter = profile.WalletBalance,
            CreatedUtc = DateTime.UtcNow
        };

        store.Ledger.Add(row);
        PersistStateSafe(cancellationToken);
        return new WalletLedgerEntryDto(row.Id, row.Amount, row.BalanceAfter, row.Type, row.Reference, row.CreatedUtc);
    }

    private AdminUserDto ToAdminUserDto(User user)
    {
        store.MemberProfiles.TryGetValue(user.Id, out var profile);
        return new AdminUserDto(user.Id, user.Username, profile?.DisplayName ?? user.Username, user.PhoneNumber, profile?.WalletBalance ?? 0, user.Role, user.CreatedUtc, profile?.LastSeenUtc ?? user.CreatedUtc);
    }

    private AdminMachineDto ToAdminMachineDto(Machine machine)
    {
        var cfg = EngineConfig.Default;
        store.MachineLedgers.TryGetValue(machine.Id, out var ledger);
        var sessions = store.MachineSessions.Values
            .Where(s => s.MachineId == machine.Id)
            .OrderByDescending(s => s.LastUpdatedUtc)
            .Select(s => new AdminMachineSessionDto(
                s.SessionId,
                s.UserId,
                store.MemberProfiles.TryGetValue(s.UserId, out var p) ? p.Username : s.UserId.ToString("N"),
                s.MachineCredits,
                s.TotalCashIn,
                s.IsMachineClosed,
                s.CounterplayScore,
                s.LastUpdatedUtc))
            .ToArray();
        var baseRtp = ledger is null || ledger.CapitalIn <= 0m ? 0m : decimal.Round(ledger.BaseCapitalOut / ledger.CapitalIn, 4);
        var activeRounds = store.ActiveRounds.Values.Count(r => r.MachineId == machine.Id && IsRoundRecoverable(r));
        var activePlayers = store.ActiveRounds.Values.Where(r => r.MachineId == machine.Id && IsRoundRecoverable(r)).Select(r => r.UserId).Distinct().Count();
        return new AdminMachineDto(
            machine.Id,
            machine.Name,
            machine.IsOpen,
            machine.MinBet,
            machine.MaxBet,
            ledger?.ObservedRtp ?? 0m,
            ledger?.TargetRtp ?? cfg.TargetRtp,
            baseRtp,
            ledger?.LastDistributionMode.ToString() ?? "Neutral",
            ledger?.LastPayoutScale ?? 0m,
            ledger?.RoundCount ?? 0,
            ledger?.ConsecutiveLosses ?? 0,
            ledger?.RoundsSinceMediumWin ?? 0,
            ledger?.CooldownRoundsRemaining ?? 0,
            ledger?.NetSinceLastClose ?? 0m,
            ledger?.RoundsSinceLucky5Hit ?? 0,
            ledger?.LastRoundUtc ?? DateTime.UtcNow,
            ledger?.JackpotFullHouse ?? cfg.JackpotFullHouseStart,
            ledger?.JackpotFullHouseRank ?? 14,
            ledger?.JackpotFourOfAKindA ?? cfg.JackpotFourOfAKindStart,
            ledger?.JackpotFourOfAKindB ?? cfg.JackpotFourOfAKindStart,
            ledger?.ActiveFourOfAKindSlot ?? 0,
            ledger?.JackpotStraightFlush ?? cfg.JackpotStraightFlushStart,
            ledger?.JackpotKent ?? cfg.JackpotKentStart,
            activeRounds,
            activePlayers,
            sessions);
    }

    private static bool IsRoundRecoverable(GameRound round)
        => !round.IsCompleted || (!round.IsPayoutSettled && round.WinAmount > 0m);

    private static string Slug(string value)
    {
        var sb = new StringBuilder();
        foreach (var ch in value.Trim())
        {
            if (char.IsLetterOrDigit(ch)) sb.Append(char.ToLowerInvariant(ch));
            else if (sb.Length == 0 || sb[^1] != '-') sb.Append('-');
        }
        var slug = sb.ToString().Trim('-');
        return slug.Length == 0 ? "note" : slug[..Math.Min(slug.Length, 40)];
    }

    private void PersistStateSafe(CancellationToken cancellationToken)
    {
        try
        {
            var snapshot = persistentStateCoordinator.CaptureAsync(cancellationToken).GetAwaiter().GetResult();
            persistentStateStore.SaveAsync(snapshot, cancellationToken).GetAwaiter().GetResult();
        }
        catch
        {
            // Best-effort persistence only.
        }
    }
}
