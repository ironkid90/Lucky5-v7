namespace Lucky5.Domain.Entities;

using Lucky5.Domain.Game.CleanRoom;

public sealed class MachineLedgerState
{
    public int MachineId { get; init; }
    public decimal TargetRtp { get; set; } = EngineConfig.Default.TargetRtp;
    public decimal CapitalIn { get; set; }
    public decimal CapitalOut { get; set; }
    public int RoundCount { get; set; }
    public int ColdStreak { get; set; }
    public int HotStreak { get; set; }
    public DistributionMode LastDistributionMode { get; set; } = DistributionMode.Neutral;
    public DateTime LastRoundUtc { get; set; } = DateTime.UtcNow;

    public decimal JackpotFullHouse { get; set; } = EngineConfig.Default.JackpotFullHouseStart;
    public int JackpotFullHouseRank { get; set; } = 14;
    public decimal JackpotFourOfAKindA { get; set; } = EngineConfig.Default.JackpotFourOfAKindStart;
    public decimal JackpotFourOfAKindB { get; set; } = EngineConfig.Default.JackpotFourOfAKindStart;
    public int ActiveFourOfAKindSlot { get; set; }
    public decimal JackpotStraightFlush { get; set; } = EngineConfig.Default.JackpotStraightFlushStart;

    public decimal BaseCapitalOut { get; set; }
    public decimal JackpotCapitalOut { get; set; }
    public decimal DoubleUpCapitalOut { get; set; }
    public decimal LastPayoutScale { get; set; } = EngineConfig.Default.DefaultPayoutScale;

    public int ConsecutiveLosses { get; set; }
    public int RoundsSinceMediumWin { get; set; }
    public int CooldownRoundsRemaining { get; set; }

    public decimal NetSinceLastClose { get; set; }
    public int LastCloseRoundNumber { get; set; }
    public WinChannel LastWinChannel { get; set; } = WinChannel.None;
    public int RoundsSinceLucky5Hit { get; set; }

    public decimal ObservedRtp => CapitalIn <= 0m ? TargetRtp : decimal.Round(CapitalOut / CapitalIn, 4);
}

public enum WinChannel
{
    None = 0,
    BaseGame = 1,
    DoubleUp = 2,
    Lucky5 = 3,
    Jackpot = 4
}
