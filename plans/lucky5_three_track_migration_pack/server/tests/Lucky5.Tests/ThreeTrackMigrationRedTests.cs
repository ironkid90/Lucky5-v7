namespace Lucky5.Tests;

using System.Text.RegularExpressions;

/// <summary>
/// RED-phase source assertions for the three-track migration.
/// These tests are intentionally source-text based so they fail before integration work starts.
/// Hook into Program.cs with: await Lucky5.Tests.ThreeTrackMigrationRedTests.RunAsync(failures);
/// </summary>
public static class ThreeTrackMigrationRedTests
{
    public static async Task RunAsync(List<string> failures)
    {
        await AssertFileContains(failures,
            "server/src/Lucky5.Infrastructure/Persistence/PersistentStateSnapshot.cs",
            @"CurrentSchemaVersion\s*=\s*2",
            "PersistentStateSnapshot should introduce schema version v2.");

        await AssertFileContains(failures,
            "server/src/Lucky5.Infrastructure/Persistence/PersistentStateCheckpointOptions.cs",
            @"TimeSpan\.FromSeconds\(10\)",
            "Persistent checkpoint interval should default to 10 seconds.");

        await AssertFileContains(failures,
            "server/src/Lucky5.Api/Program.cs",
            @"MapHealthChecks\(\s*\""/health/ready\""",
            "Program.cs should expose a readiness health endpoint.");

        await AssertFileContains(failures,
            "server/src/Lucky5.Api/Program.cs",
            @"PersistentStateHealthCheck",
            "Program.cs should register the persistence health check.");

        await AssertFileContains(failures,
            "server/src/Lucky5.Domain/Game/CleanRoom/MachinePolicy.cs",
            @"ResolvePolicy\(",
            "MachinePolicy should expose a unified ResolvePolicy entry point.");

        await AssertFileContains(failures,
            "server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs",
            @"HouseEdgeBuffer",
            "EngineConfig should include a bounded HouseEdgeBuffer control.");

        await AssertFileContains(failures,
            "server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs",
            @"JackpotRtpCap",
            "EngineConfig should include jackpot leak guardrails.");

        await AssertFileContains(failures,
            "server/src/Lucky5.Domain/Game/CleanRoom/CoreModels.cs",
            @"DoubleUpRtpCap",
            "EngineConfig should include double-up leak guardrails.");

        await AssertFileContains(failures,
            "server/src/Lucky5.Application/Dtos/MachineSessionDto.cs",
            @"MachineTransparencyDto",
            "MachineSessionDto should expose MachineTransparencyDto telemetry.");

        await AssertFileContains(failures,
            "server/src/Lucky5.Simulation/Program.cs",
            @"500_000",
            "Simulation harness should include the 500,000-round certification path.");

        await AssertFileContains(failures,
            "server/src/Lucky5.Simulation/Program.cs",
            @"78\s*[-–]\s*82|78m.*82m|0\.78m.*0\.82m",
            "Simulation gate should encode the 78-82 RTP acceptance band.");

        await AssertFileContains(failures,
            ".github/workflows/deploy-azure-app-service.yml",
            @"slot-name:\s*['\"]?staging",
            "Deployment workflow should deploy to a staging slot first.");

        await AssertFileContains(failures,
            ".github/workflows/deploy-azure-app-service.yml",
            @"az\s+webapp\s+deployment\s+slot\s+swap",
            "Deployment workflow should promote through a slot swap.");
    }

    private static async Task AssertFileContains(List<string> failures, string relativePath, string pattern, string message)
    {
        try
        {
            var content = await File.ReadAllTextAsync(ResolveRepoPath(relativePath));
            if (!Regex.IsMatch(content, pattern, RegexOptions.CultureInvariant))
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
