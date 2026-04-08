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
    .AddCheck("application", () => HealthCheckResult.Healthy("Application is running"));

// Try to add infrastructure services with error handling
try
{
    Console.WriteLine("Attempting to register infrastructure services...");
    builder.Services.AddLucky5Infrastructure(builder.Configuration);
    Console.WriteLine("Infrastructure services registered successfully");
    
    Console.WriteLine("Attempting to register realtime services...");
    builder.Services.AddLucky5Realtime();
    Console.WriteLine("Realtime services registered successfully");
    
    Console.WriteLine("Attempting to register SignalR...");
    builder.Services.AddSignalR();
    Console.WriteLine("SignalR registered successfully");
}
catch (Exception ex)
{
    Console.WriteLine($"ERROR: Failed to register services: {ex.Message}");
    Console.WriteLine($"Stack trace: {ex.StackTrace}");
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

Console.WriteLine("Building application...");
var app = builder.Build();
Console.WriteLine("Application built successfully");

// Configure middleware with error handling
try
{
    Console.WriteLine("Configuring forwarded headers...");
    app.UseForwardedHeaders();
    Console.WriteLine("Forwarded headers configured");
    
    // Try to use middleware that might fail
    try
    {
        Console.WriteLine("Adding ApiExceptionMiddleware...");
        app.UseMiddleware<ApiExceptionMiddleware>();
        Console.WriteLine("ApiExceptionMiddleware added successfully");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"ERROR: ApiExceptionMiddleware failed: {ex.Message}");
        Console.WriteLine($"Stack trace: {ex.StackTrace}");
    }
    
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
