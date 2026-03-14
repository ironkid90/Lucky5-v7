namespace Lucky5.Application.Dtos;

public sealed record AdminUserDto(
    Guid UserId,
    string Username,
    string DisplayName,
    string PhoneNumber,
    decimal WalletBalance,
    string Role,
    DateTime CreatedUtc,
    DateTime LastSeenUtc);

public sealed record AdminMachineSessionDto(
    Guid SessionId,
    Guid UserId,
    string Username,
    decimal MachineCredits,
    decimal TotalCashIn,
    bool IsMachineClosed,
    int CounterplayScore,
    DateTime LastUpdatedUtc);

public sealed record AdminMachineDto(
    int MachineId,
    string Name,
    bool IsOpen,
    decimal MinBet,
    decimal MaxBet,
    decimal ObservedRtp,
    decimal TargetRtp,
    decimal BaseRtp,
    string Phase,
    decimal LastPayoutScale,
    int RoundCount,
    int ConsecutiveLosses,
    int RoundsSinceMediumWin,
    int CooldownRemaining,
    decimal NetSinceLastClose,
    int RoundsSinceLucky5Hit,
    DateTime LastRoundUtc,
    decimal JackpotFullHouse,
    int JackpotFullHouseRank,
    decimal JackpotFourOfAKindA,
    decimal JackpotFourOfAKindB,
    int ActiveFourOfAKindSlot,
    decimal JackpotStraightFlush,
    int ActiveRounds,
    int ActivePlayers,
    IReadOnlyList<AdminMachineSessionDto> Sessions);
