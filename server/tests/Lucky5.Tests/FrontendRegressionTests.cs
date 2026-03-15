namespace Lucky5.Tests;

using System.Text.RegularExpressions;

public static class FrontendRegressionTests
{
    public static async Task RunAsync(List<string> failures)
    {
        string gameJs;
        try
        {
            gameJs = await File.ReadAllTextAsync(ResolveGameJsPath());
        }
        catch (Exception ex)
        {
            failures.Add($"Frontend regression setup failed: {ex.Message}");
            return;
        }

        Assert(
            failures,
            "initGame should preserve the selected machine and must not force machines[0] fallback",
            !gameJs.Contains("machines.find(m => m.id === machineId) || machines[0]", StringComparison.Ordinal));

        Assert(
            failures,
            "game.js should never assign machine credit balance from session.walletBalance",
            !gameJs.Contains("balance = session.walletBalance", StringComparison.Ordinal));

        var menuCashInRefreshesSession = Regex.IsMatch(
            gameJs,
            @"const\s+session\s*=\s*await\s+cashInMachine\(amount\);[\s\S]{0,600}?await\s+fetchMachineSession\(\);",
            RegexOptions.CultureInvariant);

        Assert(
            failures,
            "menu cash-in should refresh machine session state before re-enabling actions",
            menuCashInRefreshesSession);

        var menuCashOutRefreshesSession = Regex.IsMatch(
            gameJs,
            @"const\s+session\s*=\s*await\s+cashOutMachine\(\);[\s\S]{0,600}?await\s+fetchMachineSession\(\);",
            RegexOptions.CultureInvariant);

        Assert(
            failures,
            "menu cash-out should refresh machine session state before re-enabling actions",
            menuCashOutRefreshesSession);
    }

    private static string ResolveGameJsPath()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var candidate = Path.Combine(dir.FullName, "server", "src", "Lucky5.Api", "wwwroot", "js", "game.js");
            if (File.Exists(candidate))
            {
                return candidate;
            }

            dir = dir.Parent;
        }

        throw new FileNotFoundException($"Could not locate game.js from base directory '{AppContext.BaseDirectory}'");
    }

    private static void Assert(List<string> failures, string message, bool condition)
    {
        if (!condition)
        {
            failures.Add(message);
        }
    }
}
