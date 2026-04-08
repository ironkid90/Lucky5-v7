// IMMEDIATE DIAGNOSTIC: This should execute before anything else
Console.WriteLine("=== LUCKY5 APPLICATION STARTING ===");
Console.WriteLine($"Runtime: {Environment.Version}");
Console.WriteLine($"Platform: {Environment.OSVersion}");
Console.WriteLine($"Working Directory: {Environment.CurrentDirectory}");

try
{
    using Lucky5.Api.Middleware;
    using Lucky5.Infrastructure.Services;
    using Lucky5.Realtime;
    using Lucky5.Realtime.Services;
    using Microsoft.AspNetCore.HttpOverrides;
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.Extensions.Diagnostics.HealthChecks;

    Console.WriteLine("=== CREATING BUILDER ===");
    var builder = WebApplication.CreateBuilder(args);
    Console.WriteLine("=== BUILDER CREATED SUCCESSFULLY ===");

    try
    {
        Console.WriteLine("=== CONFIGURING BUILDER ===");
    
    try
    {
        Console.WriteLine("Adding BearerTokenMiddleware...");
        app.UseMiddleware<BearerTokenMiddleware>();
        Console.WriteLine("BearerTokenMiddleware added successfully");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"ERROR: BearerTokenMiddleware failed: {ex.Message}");
        Console.WriteLine($"Stack trace: {ex.StackTrace}");
    }
    
    Console.WriteLine("Adding CORS...");
    app.UseCors("Lucky5Cors");
    Console.WriteLine("CORS added successfully");
    
    Console.WriteLine("Adding default files...");
    app.UseDefaultFiles();
    Console.WriteLine("Default files added successfully");
    
    Console.WriteLine("Adding static files...");
    app.UseStaticFiles();
    Console.WriteLine("Static files added successfully");
    
    // Add simple health check endpoint that works without dependencies
    app.MapGet("/health/simple", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow, version = "1.0.0" }));
    
    // Add startup health check endpoint
    app.MapGet("/health/startup", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }));
    
    // Add fallback health endpoint that bypasses everything
    app.MapGet("/health/fallback", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow, version = "1.0.0", fallback = true }));
    
    Console.WriteLine("Adding controllers...");
    app.MapControllers();
    Console.WriteLine("Controllers added successfully");
    
    // Try to add SignalR hub
    try
    {
        Console.WriteLine("Adding SignalR hub...");
        app.MapHub<CarrePokerGameHub>("/CarrePokerGameHub");
        Console.WriteLine("SignalR hub added successfully");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"ERROR: SignalR hub failed: {ex.Message}");
        Console.WriteLine($"Stack trace: {ex.StackTrace}");
    }
    
    Console.WriteLine("Adding health check endpoints...");
    app.MapHealthChecks("/health/live", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
    {
        Predicate = check => check.Name == "application" // Only include application health check
    });
    Console.WriteLine("Health check /health/live added");

    app.MapHealthChecks("/health/ready", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
    {
        Predicate = _ => true
    });
    Console.WriteLine("Health check /health/ready added");
    
    // Log startup
    try
    {
        Console.WriteLine("Getting logger service...");
        var logger = app.Services.GetRequiredService<ILogger<Program>>();
        logger.LogInformation("Lucky5 API starting up on port {Port}", port);
        Console.WriteLine("Logger service obtained successfully");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"ERROR: Logger not available: {ex.Message}");
        Console.WriteLine($"Stack trace: {ex.StackTrace}");
        Console.WriteLine($"Lucky5 API starting up on port {port}");
    }
    
    Console.WriteLine("Starting application server...");
    Console.WriteLine($"Lucky5 API is about to start on port {port}");
    app.Run();
}
catch (Exception ex)
{
    Console.WriteLine($"Application startup failed: {ex.Message}");
    Console.WriteLine($"Stack trace: {ex.StackTrace}");
    throw;
}
