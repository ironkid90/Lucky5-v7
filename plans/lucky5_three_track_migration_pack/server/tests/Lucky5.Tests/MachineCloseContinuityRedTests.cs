namespace Lucky5.Tests;

using System.Text.RegularExpressions;

/// <summary>
/// RED-phase source assertions focused on the known 40M close-path regression.
/// These are intentionally text-based so they can be wired into the existing
/// console runner before service-level integration tests are added.
/// </summary>
public static class MachineCloseContinuityRedTests
{
    public static async Task RunAsync(List<string> failures)
    {
        await AssertFileContains(
            failures,
            "server/src/Lucky5.Infrastructure/Services/GameService.cs",
            @"idempotent|current session snapshot instead of throwing|returns the current session snapshot",
            "GameService should document or implement idempotent close-path cash-out behavior.");

        await AssertFileContains(
            failures,
            "server/src/Lucky5.Infrastructure/Services/GameService.cs",
            @"IsMachineClosed\s*=\s*false",
            "GameService cash-out flow should clear IsMachineClosed after the session is drained.");

        await AssertFileContains(
            failures,
            "server/src/Lucky5.Infrastructure/Services/GameService.cs",
            @"TotalCashIn\s*=\s*0",
            "GameService cash-out flow should reset TotalCashIn after closed-session drain.");

        await AssertFileContains(
            failures,
            "server/src/Lucky5.Infrastructure/Services/AdminService.cs",
            @"recoverable round|active round truly exists|no longer blocks merely because a closed machine session still holds credits",
            "AdminService reset path should block only on a recoverable round, not stale closed-session credits.");

        await AssertFileContains(
            failures,
            "server/src/Lucky5.Infrastructure/Persistence/PersistentStateSnapshot.cs",
            @"MachineLedgers|MachineSessions|ActiveRounds|Profiles|Users|WalletLedger",
            "Persistent snapshot should preserve ledger, session, round, profile, user, and wallet continuity across restart.");
    }

    private static async Task AssertFileContains(List<string> failures, string relativePath, string pattern, string message)
    {
        try
        {
            var content = await File.ReadAllTextAsync(ResolveRepoPath(relativePath));
            if (!Regex.IsMatch(content, pattern, RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Singleline))
            {
                failures.Add(message);
            }
        }
        catch (Exception ex)
        {
            failures.Add($"{message} (setup failed: {ex.Message})");
        }
    }

    private static string ResolveRepoPath(string relativePath)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var candidate = Path.Combine(dir.FullName, relativePath.Replace('/', Path.DirectorySeparatorChar));
            if (File.Exists(candidate))
            {
                return candidate;
            }

            dir = dir.Parent;
        }

        throw new FileNotFoundException($"Could not locate '{relativePath}' from base directory '{AppContext.BaseDirectory}'.");
    }
}
