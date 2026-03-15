namespace Lucky5.Tests;

using System.Text.RegularExpressions;

public static class FrontendRegressionTests
{
    public static async Task RunAsync(List<string> failures)
    {
        string gameJs;
        string indexHtml;
        string gameCss;
        try
        {
            gameJs = await File.ReadAllTextAsync(ResolveGameJsPath());
            indexHtml = await File.ReadAllTextAsync(ResolveIndexHtmlPath());
            gameCss = await File.ReadAllTextAsync(ResolveGameCssPath());
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

        Assert(
            failures,
            "live cabinet should render a dedicated Full House jackpot counter",
            indexHtml.Contains("id=\"jp-counter-fh\"", StringComparison.Ordinal));

        Assert(
            failures,
            "live cabinet jackpot counters should expose real 4K side slots for highlight wiring",
            indexHtml.Contains("data-jackpot-slot=\"4k-a\"", StringComparison.Ordinal)
                && indexHtml.Contains("data-jackpot-slot=\"4k-b\"", StringComparison.Ordinal));

        Assert(
            failures,
            "game.js should map the Full House jackpot value to the live Full House counter",
            Regex.IsMatch(
                gameJs,
                @"const\s+jpFh\s*=\s*document\.querySelector\('#jp-counter-fh \\.jp-cval'\);[\s\S]{0,200}?if\s*\(jpFh\)\s+jpFh\.textContent\s*=\s*formatNum\(jackpots\.fullHouse\s*\|\|\s*0\);",
                RegexOptions.CultureInvariant));

        Assert(
            failures,
            "game.js should drive the active 4K highlight from live jackpot counter nodes instead of dead jackpot-slot hooks",
            Regex.IsMatch(
                gameJs,
                @"document\.querySelectorAll\('\[data-jackpot-slot\^=\\\"4k-\\\"\]'\)",
                RegexOptions.CultureInvariant));

        Assert(
            failures,
            "game.css should define a visible active 4K jackpot counter state for live counter nodes",
            gameCss.Contains(".jp-counter.jp-active", StringComparison.Ordinal));

        Assert(
            failures,
            "win amount display should only show A/B slot tags when a 4K slot is actually relevant",
            Regex.IsMatch(
                gameJs,
                @"function\s+updateWinAmountDisplay\(amount,\s*slotTag\)\s*\{[\s\S]{0,400}?const\s+showSlotTag\s*=\s*slotTag\s*===\s*'A'\s*\|\|\s*slotTag\s*===\s*'B';",
                RegexOptions.CultureInvariant));

        Assert(
            failures,
            "jackpot win messaging should not append a duplicate jackpot amount to the main win line",
            !gameJs.Contains("JACKPOT +${formatNum(jackpotWon)}!", StringComparison.Ordinal));
    }

    private static string ResolveGameJsPath()
    {
        return ResolveWwwrootFilePath("js", "game.js");
    }

    private static string ResolveIndexHtmlPath()
    {
        return ResolveWwwrootFilePath("index.html");
    }

    private static string ResolveGameCssPath()
    {
        return ResolveWwwrootFilePath("css", "game.css");
    }

    private static string ResolveWwwrootFilePath(params string[] segments)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var candidate = Path.Combine(new[] { dir.FullName, "server", "src", "Lucky5.Api", "wwwroot" }.Concat(segments).ToArray());
            if (File.Exists(candidate))
            {
                return candidate;
            }

            dir = dir.Parent;
        }

        throw new FileNotFoundException($"Could not locate wwwroot file '{Path.Combine(segments)}' from base directory '{AppContext.BaseDirectory}'");
    }

    private static void Assert(List<string> failures, string message, bool condition)
    {
        if (!condition)
        {
            failures.Add(message);
        }
    }
}
