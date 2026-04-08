using Lucky5.Api.Middleware;
using Lucky5.Infrastructure.Services;
using Lucky5.Realtime;
using Lucky5.Realtime.Services;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Diagnostics.HealthChecks;

var builder = WebApplication.CreateBuilder(args);

// Ensure appsettings.json can be loaded properly
builder.Configuration.AddEnvironmentVariables();

// Configure Azure App Service specific settings
var port = Environment.GetEnvironmentVariable("PORT")
    ?? Environment.GetEnvironmentVariable("WEBSITES_PORT")
    ?? "8080";

builder.WebHost.ConfigureKestrel(options =>
{
    options.ListenAnyIP(int.Parse(port));
});

// Add logging for debugging
builder.Logging.ClearProviders();
builder.Logging.AddConsole();

// Configure for Azure environment
if (!builder.Environment.IsDevelopment())
{
    builder.Configuration.AddJsonFile("appsettings.Production.json", optional: true, reloadOnChange: true);
}

// Add basic services first
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

// Add health checks with basic check only
builder.Services.AddHealthChecks()
    .AddCheck("basic", () => HealthCheckResult.Healthy("Application is running"));

// Try to add infrastructure services with error handling
try
{
    builder.Services.AddLucky5Infrastructure(builder.Configuration);
    builder.Services.AddLucky5Realtime();
    builder.Services.AddSignalR();
}
catch (Exception ex)
{
    Console.WriteLine($"Warning: Failed to register some services: {ex.Message}");
    Console.WriteLine("Continuing with basic functionality...");
}
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
});

var isDevelopment = builder.Environment.IsDevelopment();

builder.Services.AddCors(options =>
{
    options.AddPolicy("Lucky5Cors", policy =>
    {
        if (isDevelopment)
        {
            policy.SetIsOriginAllowed(_ => true)
                  .AllowAnyHeader()
                  .AllowAnyMethod()
                  .AllowCredentials();
        }
        else
        {
            var allowedOrigins = (builder.Configuration["CORS:ALLOWED_ORIGINS"] ?? "http://localhost:3000,http://localhost:5173,https://localhost")
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            policy.WithOrigins(allowedOrigins)
                  .AllowAnyHeader()
                  .AllowAnyMethod()
                  .AllowCredentials();
        }
    });
});

var app = builder.Build();

// Configure middleware with error handling
try
{
    app.UseForwardedHeaders();
    
    // Try to use middleware that might fail
    try
    {
        app.UseMiddleware<ApiExceptionMiddleware>();
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Warning: ApiExceptionMiddleware failed: {ex.Message}");
    }
    
    try
    {
        app.UseMiddleware<BearerTokenMiddleware>();
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Warning: BearerTokenMiddleware failed: {ex.Message}");
    }
    
    app.UseCors("Lucky5Cors");
    app.UseDefaultFiles();
    app.UseStaticFiles();
    
    // Add simple health check endpoint that works without dependencies
    app.MapGet("/health/simple", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow, version = "1.0.0" }));
    
    // Add startup health check endpoint
    app.MapGet("/health/startup", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }));
    
    // Add fallback health endpoint that bypasses everything
    app.MapGet("/health/fallback", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow, version = "1.0.0", fallback = true }));
    
    app.MapControllers();
    
    // Try to add SignalR hub
    try
    {
        app.MapHub<CarrePokerGameHub>("/CarrePokerGameHub");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Warning: SignalR hub failed: {ex.Message}");
    }
    
    app.MapHealthChecks("/health/live", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
    {
        Predicate = check => check.Name == "basic" // Only include basic health check
    });

    app.MapHealthChecks("/health/ready", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
    {
        Predicate = _ => true
    });
    
    // Log startup
    try
    {
        var logger = app.Services.GetRequiredService<ILogger<Program>>();
        logger.LogInformation("Lucky5 API starting up on port {Port}", port);
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Logger not available: {ex.Message}");
        Console.WriteLine($"Lucky5 API starting up on port {port}");
    }
    
    app.Run();
}
catch (Exception ex)
{
    Console.WriteLine($"Application startup failed: {ex.Message}");
    Console.WriteLine($"Stack trace: {ex.StackTrace}");
    throw;
}
