using Lucky5.Api.Middleware;
using Lucky5.Infrastructure.Services;
using Lucky5.Realtime;
using Lucky5.Realtime.Services;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Mvc;

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

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSignalR();
builder.Services.AddHealthChecks();
builder.Services.AddLucky5Infrastructure(builder.Configuration);
builder.Services.AddLucky5Realtime();
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
    app.UseMiddleware<ApiExceptionMiddleware>();
    app.UseMiddleware<BearerTokenMiddleware>();
    app.UseCors("Lucky5Cors");
    app.UseDefaultFiles();
    app.UseStaticFiles();
    
    // Add basic health check endpoint for startup
    app.MapGet("/health/startup", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }));
    
    app.MapControllers();
    app.MapHub<CarrePokerGameHub>("/CarrePokerGameHub");
    app.MapHealthChecks("/health/live", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
    {
        Predicate = check => check.Name != "persistence" // Exclude persistence from live check
    });

    app.MapHealthChecks("/health/ready", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
    {
        Predicate = _ => true
    });
    
    // Log startup
    var logger = app.Services.GetRequiredService<ILogger<Program>>();
    logger.LogInformation("Lucky5 API starting up on port {Port}", port);
    
    app.Run();
}
catch (Exception ex)
{
    var logger = app.Services.GetRequiredService<ILogger<Program>>();
    logger.LogError(ex, "Application startup failed");
    throw;
}
