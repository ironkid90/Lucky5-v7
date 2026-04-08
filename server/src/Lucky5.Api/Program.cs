// Test with infrastructure services - identify problematic component
using Lucky5.Infrastructure.Services;

Console.WriteLine("=== TEST: STARTING ===");

var builder = WebApplication.CreateBuilder(args);
Console.WriteLine("=== TEST: BUILDER CREATED ===");

builder.Services.AddControllers();
Console.WriteLine("=== TEST: CONTROLLERS ADDED ===");

// Skip infrastructure services for now - causing 503 errors
Console.WriteLine("=== TEST: SKIPPING INFRASTRUCTURE - CAUSING 503 ERRORS ===");

var app = builder.Build();
Console.WriteLine("=== TEST: APP BUILT ===");

app.MapGet("/", () => $"Lucky5 API v2.0 - Deployed at {DateTime.UtcNow:yyyy-MM-dd HH:mm:ss} UTC");
Console.WriteLine("=== TEST: ENDPOINT MAPPED ===");

app.MapGet("/health", () => new { status = "healthy" });
Console.WriteLine("=== TEST: HEALTH ENDPOINT MAPPED ===");

app.MapGet("/health/fallback", () => new { status = "healthy", timestamp = DateTime.UtcNow });
Console.WriteLine("=== TEST: FALLBACK HEALTH ENDPOINT MAPPED ===");

Console.WriteLine("=== TEST: STARTING APP ===");
app.Run();
