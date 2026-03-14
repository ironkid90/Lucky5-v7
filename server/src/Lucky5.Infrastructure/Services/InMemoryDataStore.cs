namespace Lucky5.Infrastructure.Services;

using Lucky5.Domain.Entities;
using Lucky5.Domain.Game.CleanRoom;

public sealed class InMemoryDataStore
{
    public InMemoryDataStore()
    {
        foreach (var machine in Machines)
        {
            MachineLedgers[machine.Id] = new MachineLedgerState
            {
                MachineId = machine.Id,
                TargetRtp = EngineConfig.Default.TargetRtp
            };
        }

        var adminId = Guid.Parse("00000000-0000-0000-0000-000000000001");
        var adminUsername = Environment.GetEnvironmentVariable("LUCKY5_ADMIN_USERNAME") ?? "admin";
        var adminPassword = Environment.GetEnvironmentVariable("LUCKY5_ADMIN_PASSWORD") ?? "admin123";
        var adminPhone = Environment.GetEnvironmentVariable("LUCKY5_ADMIN_PHONE") ?? "+96100000000";

        Users[adminId] = new User
        {
            Id = adminId,
            Username = adminUsername,
            PasswordHash = adminPassword,
            PhoneNumber = adminPhone,
            IsOtpVerified = true,
            Role = "admin",
            CreatedUtc = DateTime.UtcNow
        };

        Profiles[adminId] = new MemberProfile
        {
            UserId = adminId,
            Username = adminUsername,
            DisplayName = "System Admin",
            PhoneNumber = adminPhone,
            WalletBalance = 5_000_000m,
            LastSeenUtc = DateTime.UtcNow
        };
    }

    public object LedgerSync { get; } = new();

    public Dictionary<Guid, User> Users { get; } = new();
    public Dictionary<Guid, MemberProfile> Profiles { get; } = new();
    public List<WalletLedgerEntry> Ledger { get; } = [];
    public Dictionary<Guid, GameRound> ActiveRounds { get; } = new();
    public Dictionary<string, MachineSessionState> MachineSessions { get; } = new(StringComparer.OrdinalIgnoreCase);
    public Dictionary<int, MachineLedgerState> MachineLedgers { get; } = new();
    public List<Machine> Machines { get; } =
    [
        new() { Id = 1, Name = "Lucky 5 - Beirut", MinBet = 5000, MaxBet = 10000, IsOpen = true },
        new() { Id = 2, Name = "Lucky 5 - Hamra", MinBet = 5000, MaxBet = 10000, IsOpen = true },
        new() { Id = 3, Name = "Lucky 5 - VIP", MinBet = 5000, MaxBet = 10000, IsOpen = true }
    ];

    public List<Offer> Offers { get; } =
    [
        new() { Id = 1, Title = "Welcome Bonus", Description = "First deposit bonus", BonusAmount = 10 },
        new() { Id = 2, Title = "Weekend Cashback", Description = "5% cashback on losses", BonusAmount = 5 }
    ];

    public List<ContactType> ContactTypes { get; } =
    [
        new() { Id = 1, Name = "Technical" },
        new() { Id = 2, Name = "Billing" },
        new() { Id = 3, Name = "General" }
    ];

    public List<ContactReport> ContactReports { get; } = [];

    public TermsDocument Terms { get; } = new()
    {
        Version = "1.0.0",
        BodyMarkdown = "# Terms\n\nUse this clean-room build for testing and internal validation only.",
        UpdatedUtc = DateTime.UtcNow
    };

    public Dictionary<string, string> AppSettings { get; } = new(StringComparer.OrdinalIgnoreCase)
    {
        ["game.houseRulesetVersion"] = "v2",
        ["signalr.heartbeatSeconds"] = "20",
        ["wallet.currency"] = "USD"
    };

    public Dictionary<string, string> ContactInfo { get; } = new(StringComparer.OrdinalIgnoreCase)
    {
        ["email"] = "support@lucky5.local",
        ["phone"] = "+961-01-000-000"
    };
}
