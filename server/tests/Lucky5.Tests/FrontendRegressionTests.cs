namespace Lucky5.Tests;

using System.Text.RegularExpressions;

public static class FrontendRegressionTests
{
    public static async Task RunAsync(List<string> failures)
    {
        string gameJs;
        string gameConfigJs;
        string indexHtml;
        string gameCss;
        string orchestratorJs;
        try
        {
            gameJs = await File.ReadAllTextAsync(ResolveGameJsPath());
            gameConfigJs = await File.ReadAllTextAsync(ResolveWwwrootFilePath("js", "game-config.js"));
            indexHtml = await File.ReadAllTextAsync(ResolveIndexHtmlPath());
            gameCss = await File.ReadAllTextAsync(ResolveGameCssPath());
            orchestratorJs = await File.ReadAllTextAsync(ResolveWwwrootFilePath("js", "cabinet-orchestrator-vnext.js"));
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
            "game.js should not default the selected machine to machine 1 before the player picks a cabinet",
            !gameJs.Contains("let machineId = 1;", StringComparison.Ordinal));

        Assert(
            failures,
            "game.js should never assign machine credit balance from session.walletBalance",
            !gameJs.Contains("balance = session.walletBalance", StringComparison.Ordinal));

        Assert(
            failures,
            "game.js should normalize machine-credit response fields through a dedicated sync helper",
            Regex.IsMatch(
                gameJs,
                @"function\s+syncMachineCreditsFromResponse\(source\)\s*\{[\s\S]{0,600}?walletBalanceAfterBet[\s\S]{0,250}?walletBalanceAfterRound[\s\S]{0,250}?walletBalance[\s\S]{0,250}?updateCredits\(\);",
                RegexOptions.CultureInvariant));

        Assert(
            failures,
            "game.js should not directly map result.walletBalance into machine credit state",
            !Regex.IsMatch(gameJs, @"balance\s*=\s*result\.walletBalance\b", RegexOptions.CultureInvariant));

        Assert(
            failures,
            "menu cash-in should refresh machine session state before re-enabling actions",
            Regex.IsMatch(
                gameJs,
                @"const\s+session\s*=\s*await\s+cashInMachine\(amount\);[\s\S]{0,600}?await\s+fetchMachineSession\(\);",
                RegexOptions.CultureInvariant));

        Assert(
            failures,
            "menu cash-in should restore idle machine UI state after refreshing the machine session",
            Regex.IsMatch(
                gameJs,
                @"const\s+session\s*=\s*await\s+cashInMachine\(amount\);[\s\S]{0,600}?await\s+fetchMachineSession\(\);[\s\S]{0,250}?refreshIdleMachineState\(",
                RegexOptions.CultureInvariant));

        Assert(
            failures,
            "menu cash-out should refresh machine session state before re-enabling actions",
            Regex.IsMatch(
                gameJs,
                @"const\s+session\s*=\s*await\s+cashOutMachine\(\);[\s\S]{0,600}?await\s+fetchMachineSession\(\);",
                RegexOptions.CultureInvariant));

        Assert(
            failures,
            "menu cash-out should restore idle machine UI state after refreshing the machine session",
            Regex.IsMatch(
                gameJs,
                @"const\s+session\s*=\s*await\s+cashOutMachine\(\);[\s\S]{0,600}?await\s+fetchMachineSession\(\);[\s\S]{0,250}?refreshIdleMachineState\(",
                RegexOptions.CultureInvariant));

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
            gameJs.Contains("const jpFh = document.querySelector('#jp-counter-fh .jp-cval');", StringComparison.Ordinal)
                && gameJs.Contains("if (jpFh) jpFh.textContent = formatNum(jackpots.fullHouse || 0);", StringComparison.Ordinal));

        Assert(
            failures,
            "game.js should drive the active 4K highlight from live jackpot counter nodes instead of dead jackpot-slot hooks",
            gameJs.Contains("document.querySelectorAll('[data-jackpot-slot^=\"4k-\"]')", StringComparison.Ordinal));

        Assert(
            failures,
            "game.css should define a visible active 4K jackpot counter state for live counter nodes",
            gameCss.Contains(".jp-counter.jp-active", StringComparison.Ordinal));

        Assert(
            failures,
            "paytable colors should map royal flush to yellow and full house to light blue for screenshot parity",
            gameCss.Contains(".pay-row.rf { color: #ffd84d; }", StringComparison.Ordinal)
                && gameCss.Contains(".pay-row.fh { color: #7fd7ff; }", StringComparison.Ordinal));

        Assert(
            failures,
            "paytable jackpot-selected row should continue to highlight the Full House row for the selected jackpot rank",
            gameJs.Contains("const fhRow = document.querySelector('.pay-row.fh');", StringComparison.Ordinal)
                && gameJs.Contains("if (fhRow) fhRow.classList.add('jackpot-selected');", StringComparison.Ordinal));

        Assert(
            failures,
            "jackpot counters should use white baseline text with green 4K side counters and red center counter",
            Regex.IsMatch(
                gameCss,
                @"\.jp-counter\s*\{[\s\S]{0,180}?color:\s*#ffffff;",
                RegexOptions.CultureInvariant)
                && gameCss.Contains("#jp-counter-a,", StringComparison.Ordinal)
                && gameCss.Contains("#jp-counter-center {", StringComparison.Ordinal));

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

        Assert(
            failures,
            "game.js should define a dedicated helper for the active-round hydration endpoint",
            Regex.IsMatch(
                gameJs,
                @"function\s+getMachineActiveRoundPath\(targetMachineId\s*=\s*machineId\)\s*\{[\s\S]{0,200}?/api/Game/machine/\$\{targetMachineId\}/active-round",
                RegexOptions.CultureInvariant));

        Assert(
            failures,
            "fetchActiveRoundState should hydrate through the shared active-round path helper",
            Regex.IsMatch(
                gameJs,
                @"async\s+function\s+fetchActiveRoundState\(\)\s*\{[\s\S]{0,120}?getMachineActiveRoundPath\(\)",
                RegexOptions.CultureInvariant));

        Assert(
            failures,
            "game.js should restore recoverable rounds through a dedicated snapshot hydrator",
            Regex.IsMatch(
                gameJs,
                @"function\s+restoreRoundFromSnapshot\(snapshot\)\s*\{[\s\S]{0,1600}?snapshot\.phase[\s\S]{0,1600}?snapshot\.cards",
                RegexOptions.CultureInvariant));

        Assert(
            failures,
            "initGame should restore active rounds before falling back to idle cabinet state",
            Regex.IsMatch(
                gameJs,
                @"const\s+activeRound\s*=\s*await\s+fetchActiveRoundState\(\);[\s\S]{0,500}?if\s*\(activeRound\)\s*\{[\s\S]{0,500}?restoreRoundFromSnapshot\(activeRound\);",
                RegexOptions.CultureInvariant));

        Assert(
            failures,
            "saved machine restore should allow lobby fallback instead of blindly trapping empty sessions in game view",
            gameJs.Contains("initGame({ allowLobbyFallback: true })", StringComparison.Ordinal));

        Assert(
            failures,
            "allowLobbyFallback should clear remembered machine selection and return safely to the lobby when no active round exists",
            Regex.IsMatch(
                gameJs,
                @"if\s*\(allowLobbyFallback\)\s*\{[\s\S]{0,180}?clearCurrentMachineSelection\(\);[\s\S]{0,120}?await\s+showLobby\(\);[\s\S]{0,80}?return;",
                RegexOptions.CultureInvariant));

        Assert(
            failures,
            "game.js should route lobby, wallet, admin, and game activation through shared shell helpers",
            Regex.IsMatch(
                gameJs,
                @"function\s+setActiveScreen\(screenName\)\s*\{[\s\S]{0,1200}?\['lobby','wallet','admin','game'\]",
                RegexOptions.CultureInvariant)
                && Regex.IsMatch(
                    gameJs,
                    @"function\s+activateShellScreen\(screenName,\s*navTarget\s*=\s*screenName\s*===\s*'game'\s*\?\s*null\s*:\s*screenName\)",
                    RegexOptions.CultureInvariant)
                && gameJs.Contains("activateShellScreen('game', null);", StringComparison.Ordinal)
                && gameJs.Contains("activateShellScreen('lobby', 'lobby');", StringComparison.Ordinal)
                && gameJs.Contains("activateShellScreen('wallet', 'wallet');", StringComparison.Ordinal)
                && gameJs.Contains("activateShellScreen('admin', 'admin');", StringComparison.Ordinal));

        Assert(
            failures,
            "game.js should centralize menu panel visibility through setMenuPanelOpen instead of scattered inline display toggles",
            Regex.IsMatch(
                gameJs,
                @"function\s+setMenuPanelOpen\(isOpen\)\s*\{[\s\S]{0,400}?classList\.(add|toggle)\('is-open'",
                RegexOptions.CultureInvariant));

        Assert(
            failures,
            "menu panel markup should move away from giant inline overlay styling",
            indexHtml.Contains("id=\"menu-panel\" class=\"menu-panel\"", StringComparison.Ordinal)
                && !Regex.IsMatch(indexHtml, @"<div\s+id=""menu-panel""\s+style=", RegexOptions.CultureInvariant));

        Assert(
            failures,
            "menu panel should own the Back to Lobby action instead of a separate game back bar",
            Regex.IsMatch(
                indexHtml,
                @"<div\s+id=""menu-panel""[\s\S]{0,500}?id=""game-back-lobby""",
                RegexOptions.CultureInvariant)
                && !indexHtml.Contains("id=\"game-back-bar\"", StringComparison.Ordinal));

        Assert(
            failures,
            "game.js should centralize machine close copy and CTA emphasis through a dedicated helper",
            Regex.IsMatch(
                gameJs,
                @"function\s+getMachineCloseMessage\(context\s*=\s*'menu'\)",
                RegexOptions.CultureInvariant)
                && gameJs.Contains("getMachineCloseMessage('take-score')", StringComparison.Ordinal)
                && gameJs.Contains("getMachineCloseMessage('cashing-out')", StringComparison.Ordinal)
                && gameJs.Contains("showMessage(getMachineCloseMessage(), 'win');", StringComparison.Ordinal));

        Assert(
            failures,
            "player and admin machine reset actions should use their dedicated routes instead of sharing brittle inline endpoints",
            Regex.IsMatch(
                gameJs,
                @"function\s+getPlayerMachineResetPath\(targetMachineId\s*=\s*machineId\)",
                RegexOptions.CultureInvariant)
                && Regex.IsMatch(
                    gameJs,
                    @"function\s+getAdminMachineResetPath\(targetMachineId\)",
                    RegexOptions.CultureInvariant)
                && gameJs.Contains("await apiCall('POST', getPlayerMachineResetPath());", StringComparison.Ordinal)
                && gameJs.Contains("await apiCall('POST', getAdminMachineResetPath(btn.dataset.resetMachine));", StringComparison.Ordinal));

        Assert(
            failures,
            "critical shell buttons should be wired to concrete handlers",
            gameJs.Contains("lobbyWalletBtn.addEventListener('click', showWallet);", StringComparison.Ordinal)
                && gameJs.Contains("walletBackBtn.addEventListener('click', showLobby);", StringComparison.Ordinal)
                && gameJs.Contains("adminBackBtn.addEventListener('click', showLobby);", StringComparison.Ordinal)
                && gameJs.Contains("navLobby.addEventListener('click', showLobby);", StringComparison.Ordinal)
                && gameJs.Contains("navWallet.addEventListener('click', showWallet);", StringComparison.Ordinal)
                && gameJs.Contains("navAdmin.addEventListener('click', showAdmin);", StringComparison.Ordinal)
                && gameJs.Contains("gameBackBtn.addEventListener('click', async () =>", StringComparison.Ordinal));

        Assert(
            failures,
            "index.html should load the vnext cabinet adapter scripts",
            indexHtml.Contains("/js/cabinet-state-vnext.js", StringComparison.Ordinal)
                && indexHtml.Contains("/js/cabinet-audio-vnext.js", StringComparison.Ordinal)
                && indexHtml.Contains("/js/cabinet-transition-vnext.js", StringComparison.Ordinal)
                && indexHtml.Contains("/js/cabinet-orchestrator-vnext.js", StringComparison.Ordinal));

        Assert(
            failures,
            "index.html should load the cabinet frame stylesheet",
            indexHtml.Contains("/css/cabinet-frame-vnext.css", StringComparison.Ordinal));

        Assert(
            failures,
            "index.html should only define one take-score button id",
            Regex.Matches(indexHtml, "id=\"btn-take-score\"", RegexOptions.CultureInvariant).Count == 1);

        Assert(
            failures,
            "game-config.js should define cabinet layout and audio event config for the vnext modules",
            gameConfigJs.Contains("cabinet: Object.freeze(", StringComparison.Ordinal)
                && gameConfigJs.Contains("audio: Object.freeze(", StringComparison.Ordinal));

        Assert(
            failures,
            "cabinet-orchestrator-vnext.js should expose render_game_to_text and advanceTime debug hooks",
            orchestratorJs.Contains("window.render_game_to_text = function renderGameToText()", StringComparison.Ordinal)
                && orchestratorJs.Contains("window.advanceTime = function advanceTime(ms)", StringComparison.Ordinal));

        Assert(
            failures,
            "cabinet-orchestrator-vnext.js should guard patching behind function existence checks",
            orchestratorJs.Contains("if (typeof window[name] === 'function' || typeof globalThis[name] === 'function')", StringComparison.Ordinal));

        Assert(
            failures,
            "cabinet-orchestrator-vnext.js should keep original functions available for debugging",
            orchestratorJs.Contains("const originals = {};", StringComparison.Ordinal)
                && Regex.IsMatch(
                    orchestratorJs,
                    @"return\s*\{\s*install,\s*originals\s*\}",
                    RegexOptions.CultureInvariant));
    }

    private static string ResolveGameJsPath()
        => ResolveWwwrootFilePath("js", "game.js");

    private static string ResolveIndexHtmlPath()
        => ResolveWwwrootFilePath("index.html");

    private static string ResolveGameCssPath()
        => ResolveWwwrootFilePath("css", "game.css");

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
