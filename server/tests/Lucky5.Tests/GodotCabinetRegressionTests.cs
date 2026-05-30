namespace Lucky5.Tests;

public static class GodotCabinetRegressionTests
{
    public static async Task RunAsync(List<string> failures)
    {
        string project;
        string mainScene;
        string rootScript;
        string apiScript;
        try
        {
            project = await File.ReadAllTextAsync(ResolveRepoFilePath("godot", "cabinet", "project.godot"));
            mainScene = await File.ReadAllTextAsync(ResolveRepoFilePath("godot", "cabinet", "scenes", "CabinetRoot.tscn"));
            rootScript = await File.ReadAllTextAsync(ResolveRepoFilePath("godot", "cabinet", "scripts", "cabinet_root.gd"));
            apiScript = await File.ReadAllTextAsync(ResolveRepoFilePath("godot", "cabinet", "scripts", "cabinet_api.gd"));
        }
        catch (Exception ex)
        {
            failures.Add($"Godot cabinet regression setup failed: {ex.Message}");
            return;
        }

        Assert(
            failures,
            "Godot cabinet project must launch CabinetRoot.tscn as the playable main scene",
            project.Contains("run/main_scene=\"res://scenes/CabinetRoot.tscn\"", StringComparison.Ordinal));

        Assert(
            failures,
            "CabinetRoot.tscn must attach cabinet_root.gd so the playable UI, API client, and controls are created on launch",
            mainScene.Contains("path=\"res://scripts/cabinet_root.gd\"", StringComparison.Ordinal)
                && mainScene.Contains("script = ExtResource", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet must expose an in-app username/password auth panel instead of requiring LUCKY5_ACCESS_TOKEN injection",
            rootScript.Contains("username_edit", StringComparison.Ordinal)
                && rootScript.Contains("password_edit", StringComparison.Ordinal)
                && rootScript.Contains("_on_login_pressed", StringComparison.Ordinal)
                && rootScript.Contains("_on_signup_pressed", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet API must support Auth login/signup/OTP verification endpoints for first-class playable bootstrap",
            apiScript.Contains("func login(", StringComparison.Ordinal)
                && apiScript.Contains("/api/Auth/login", StringComparison.Ordinal)
                && apiScript.Contains("func signup(", StringComparison.Ordinal)
                && apiScript.Contains("/api/Auth/signup", StringComparison.Ordinal)
                && apiScript.Contains("func verify_otp(", StringComparison.Ordinal)
                && apiScript.Contains("/api/Auth/verify-otp", StringComparison.Ordinal));
    }

    private static string ResolveRepoFilePath(params string[] segments)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var candidate = Path.Combine(new[] { dir.FullName }.Concat(segments).ToArray());
            if (File.Exists(candidate))
            {
                return candidate;
            }

            dir = dir.Parent;
        }

        throw new FileNotFoundException($"Could not locate repo file '{Path.Combine(segments)}' from base directory '{AppContext.BaseDirectory}'");
    }

    private static void Assert(List<string> failures, string message, bool condition)
    {
        if (!condition)
        {
            failures.Add(message);
        }
    }
}
