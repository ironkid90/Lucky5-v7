// IMMEDIATE DIAGNOSTIC: This should execute before anything else
Console.WriteLine("=== LUCKY5 APPLICATION STARTING ===");
Console.WriteLine($"Runtime: {Environment.Version}");
Console.WriteLine($"Platform: {Environment.OSVersion}");
Console.WriteLine($"Working Directory: {Environment.CurrentDirectory}");

using Lucky5.Api.Middleware;
using Lucky5.Infrastructure.Services;
using Lucky5.Realtime;
using Lucky5.Realtime.Services;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Diagnostics.HealthChecks;

try
{

    Console.WriteLine("=== CREATING BUILDER ===");
    var builder = WebApplication.CreateBuilder(args);
    Console.WriteLine("=== BUILDER CREATED SUCCESSFULLY ===");

    Console.WriteLine("=== CONFIGURING BUILDER ===");
    
    // Ensure appsettings.json can be loaded properly
    builder.Configuration.AddEnvironmentVariables();
    Console.WriteLine("=== ENVIRONMENT VARIABLES ADDED ===");

    // Configure Azure App Service specific settings
    var port = Environment.GetEnvironmentVariable("PORT")
        ?? Environment.GetEnvironmentVariable("WEBSITES_PORT")
        ?? "8080";
    Console.WriteLine($"=== PORT CONFIGURED: {port} ===");

    builder.WebHost.ConfigureKestrel(options =>
    {
        options.ListenAnyIP(int.Parse(port));
    });
    Console.WriteLine("=== KESTREL CONFIGURED ===");

    // Add logging for debugging
    builder.Logging.ClearProviders();
    builder.Logging.AddConsole();
    Console.WriteLine("=== LOGGING CONFIGURED ===");

    // Configure for Azure environment
    if (!builder.Environment.IsDevelopment())
    {
        builder.Configuration.AddJsonFile("appsettings.Production.json", optional: true, reloadOnChange: true);
        Console.WriteLine("=== PRODUCTION CONFIGURATION LOADED ===");
    }

    // Add basic services first
    builder.Services.AddControllers();
    builder.Services.AddEndpointsApiExplorer();
    Console.WriteLine("=== BASIC SERVICES ADDED ===");

    // Add health checks with basic check only
    builder.Services.AddHealthChecks()
        .AddCheck("application", () => HealthCheckResult.Healthy("Application is running"));
    Console.WriteLine("=== HEALTH CHECKS ADDED ===");

    Console.WriteLine("=== BUILDING APPLICATION ===");
    var app = builder.Build();
    Console.WriteLine("=== APPLICATION BUILT SUCCESSFULLY ===");

    Console.WriteLine("=== CONFIGURING MIDDLEWARE ===");
    app.UseForwardedHeaders(new ForwardedHeadersOptions
    {
        ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
    });
    app.UseRouting();
    app.UseCors();
    app.UseAuthentication();
    app.UseAuthorization();
    app.MapControllers();
    Console.WriteLine("=== MIDDLEWARE CONFIGURED ===");

    // Add health check endpoints
    app.MapHealthChecks("/health/fallback", new HealthCheckOptions
    {
        Predicate = _ => false // No health checks - always returns 200
    });
    Console.WriteLine("=== HEALTH ENDPOINTS CONFIGURED ===");

    Console.WriteLine("=== STARTING APPLICATION ===");
    app.Run();
}
catch (Exception ex)
{
    Console.WriteLine("=== FATAL ERROR ===");
    Console.WriteLine($"Message: {ex.Message}");
    Console.WriteLine($"Stack Trace: {ex.StackTrace}");
    Console.WriteLine("=== APPLICATION FAILED TO START ===");
    throw;
}
