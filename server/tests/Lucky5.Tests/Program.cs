using Lucky5.Application.Contracts;
using Lucky5.Domain.Entities;
using Lucky5.Domain.Game;
using Lucky5.Domain.Game.CleanRoom;
using Lucky5.Infrastructure.Services;
using Lucky5.Application.Requests;
using Microsoft.Extensions.Configuration;

var failures = new List<string>();

void Assert(bool condition, string message)
{
    if (!condition)
    {
        failures.Add(message);
    }
}

var royalFlush = new List<PokerCard>
{
    new("10", "H"),
    new("J", "H"),
    new("Q", "H"),
    new("K", "H"),
    new("A", "H")
};

var twoPair = new List<PokerCard>
{
    new("A", "S"),
    new("A", "D"),
    new("8", "C"),
    new("8", "H"),
    new("2", "S")
};

var noWin = new List<PokerCard>
{
    new("2", "S"),
    new("4", "D"),
    new("6", "C"),
    new("8", "H"),
    new("10", "S")
};

var rf = PokerHandEvaluator.Evaluate(royalFlush);
Assert(rf.Rank == "RoyalFlush" && rf.Multiplier == 250m, "Royal flush payout mismatch");

var tp = PokerHandEvaluator.Evaluate(twoPair);
Assert(tp.Rank == "TwoPair" && tp.Multiplier == 2m, "Two pair payout mismatch");

var nw = PokerHandEvaluator.Evaluate(noWin);
Assert(nw.Rank == "NoWin" && nw.Multiplier == 0m, "NoWin payout mismatch");

var configuration = new ConfigurationBuilder()
    .AddInMemoryCollection(new Dictionary<string, string?> { ["JWT:SIGNING_KEY"] = "test-signing-key" })
    .Build();

var store = new InMemoryDataStore();
var tokenService = new SimpleTokenService(configuration);
var authService = new AuthService(store, tokenService);
var gameService = new GameService(store, new DefaultEntropyGenerator());

var profile = await authService.SignupAsync(new SignupRequest("tester", "password", "+9610000000"), CancellationToken.None);
Assert(profile.Username == "tester", "Signup should return created profile");

var otpVerified = await authService.VerifyOtpAsync(new VerifyOtpRequest("tester", "123456"), CancellationToken.None);
Assert(otpVerified, "OTP should verify using bootstrap code");

var login = await authService.LoginAsync(new LoginRequest("tester", "password"), CancellationToken.None);
Assert(login.Tokens.AccessToken.Length > 10, "Login should issue access token");

var machine = (await gameService.GetMachinesAsync(CancellationToken.None)).First();
Assert(EngineConfig.Default.CloseThreshold == 40_000_000m, "Engine config should lower machine close threshold to 40,000,000 credits");
Assert(store.MachineLedgers[machine.Id].TargetRtp == EngineConfig.Default.TargetRtp, "Machine ledger should inherit the approved 85% RTP target");
Assert(store.MachineLedgers[machine.Id].JackpotStraightFlush == EngineConfig.Default.JackpotStraightFlushStart, "Machine ledger should inherit the approved straight-flush jackpot reset value");
var cashIn = await gameService.CashInAsync(profile.UserId, machine.Id, 200_000m, CancellationToken.None);
Assert(cashIn.MachineCredits == 200_000m, "Cash-in should fund the machine session");

var beforeDeal = cashIn.MachineCredits;
var deal = await gameService.DealAsync(profile.UserId, new DealRequest(machine.Id, machine.MinBet), CancellationToken.None);
Assert(deal.Cards.Count == 5, "Deal should return 5 cards");
Assert(deal.WalletBalanceAfterBet == beforeDeal - machine.MinBet, "Deal should debit machine credits for the initial bet");

var draw = await gameService.DrawAsync(profile.UserId, new DrawRequest(deal.RoundId, [0, 1, 2, 3, 4]), CancellationToken.None);
Assert(draw.Cards.Count == 5, "Draw should return 5 cards");
Assert(draw.WalletBalanceAfterRound >= 0, "Draw should leave a non-negative machine credit balance");

var history = await authService.GetMemberHistoryAsync(profile.UserId, CancellationToken.None);
Assert(history.Count >= 1, "Wallet history should contain at least bet entry");
Assert(store.MachineLedgers[machine.Id].CapitalIn >= machine.MinBet, "Machine ledger should track capital-in after deal");

var uniqueOpeningHands = new HashSet<string>(StringComparer.Ordinal);
for (var i = 0; i < 12; i++)
{
    var rDeal = await gameService.DealAsync(profile.UserId, new DealRequest(machine.Id, machine.MinBet), CancellationToken.None);
    uniqueOpeningHands.Add(string.Join(",", rDeal.Cards.Select(c => c.Code)));
    await gameService.DrawAsync(profile.UserId, new DrawRequest(rDeal.RoundId, []), CancellationToken.None);
}

Assert(uniqueOpeningHands.Count >= 4, "Card distribution should produce diverse openings under entropy/noise model");

var modeState = await gameService.GetMachineStateAsync(machine.Id, CancellationToken.None);
Assert(modeState is not null, "Machine state should be available");

// Deterministic Replay Tests
await Lucky5.Tests.ReplayTests.RunAsync(failures);
await Lucky5.Tests.CleanRoomEngineTests.RunAsync(failures);

if (draw.WinAmount > 0)
{
    var result = await gameService.DoubleUpAsync(profile.UserId, new DoubleUpRequest(draw.RoundId, "big"), CancellationToken.None);
    Assert(result.Status is "Won" or "Lost" or "Unavailable", "Double-up should resolve predictably when there is a prior win");
}

var guardedRound = new GameRound
{
    UserId = profile.UserId,
    MachineId = machine.Id,
    IsCompleted = true,
    WinAmount = 5000,
    OriginalWinAmount = 5000,
    DoubleUpOffered = false,
    RoundEntropySeed = 123456789UL
};
store.ActiveRounds[guardedRound.RoundId] = guardedRound;

var guardedLegacyResult = await gameService.DoubleUpAsync(
    profile.UserId,
    new DoubleUpRequest(guardedRound.RoundId, "big"),
    CancellationToken.None);
Assert(guardedLegacyResult.Status == "Unavailable", "Legacy double-up should report unavailable instead of throwing when gated off");
Assert(guardedLegacyResult.UpdatedWinAmount == guardedRound.WinAmount, "Unavailable double-up should preserve the current win amount");

var takeHalfRound = new GameRound
{
    UserId = profile.UserId,
    MachineId = machine.Id,
    IsCompleted = true,
    WinAmount = 8000,
    OriginalWinAmount = 8000,
    DoubleUpOffered = true,
    RoundEntropySeed = 987654321UL
};
store.ActiveRounds[takeHalfRound.RoundId] = takeHalfRound;

var takeHalfResult = await gameService.TakeHalfAsync(profile.UserId, takeHalfRound.RoundId, CancellationToken.None);
Assert(takeHalfResult.CurrentAmount == 4000, "Take-half should leave half the amount in play");

var takeHalfSecondAttemptBlocked = false;
try
{
    await gameService.TakeHalfAsync(profile.UserId, takeHalfRound.RoundId, CancellationToken.None);
}
catch (InvalidOperationException ex) when (ex.Message.Contains("Take-half already used", StringComparison.Ordinal))
{
    takeHalfSecondAttemptBlocked = true;
}

Assert(takeHalfSecondAttemptBlocked, "Take-half should only be allowed once per round");

var postSplitStart = await gameService.StartDoubleUpAsync(profile.UserId, takeHalfRound.RoundId, CancellationToken.None);
Assert(postSplitStart.Status == "Started", "Double-up should still start on the remaining amount after taking half once");

if (failures.Count > 0)
{
    Console.Error.WriteLine("Lucky5 bootstrap tests failed:");
    foreach (var failure in failures)
    {
        Console.Error.WriteLine($"- {failure}");
    }

    Environment.Exit(1);
}

Console.WriteLine("Lucky5 bootstrap tests passed.");
