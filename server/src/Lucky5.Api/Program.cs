// Test with infrastructure services - identify problematic component
using Lucky5.Infrastructure.Services;

Console.WriteLine("=== TEST: STARTING ===");

var builder = WebApplication.CreateBuilder(args);
Console.WriteLine("=== TEST: BUILDER CREATED ===");

builder.Services.AddControllers();
Console.WriteLine("=== TEST: CONTROLLERS ADDED ===");

// Add infrastructure services step by step
Console.WriteLine("=== TEST: ADDING INFRASTRUCTURE ===");
try
{
    // Add the missing using directive for infrastructure services
    builder.Services.AddLucky5Infrastructure(builder.Configuration);
    Console.WriteLine("=== TEST: INFRASTRUCTURE ADDED SUCCESSFULLY ===");
}
catch (Exception ex)
{
    Console.WriteLine($"=== TEST: INFRASTRUCTURE FAILED: {ex.Message} ===");
    Console.WriteLine("=== TEST: SKIPPING INFRASTRUCTURE - CONTINUING WITHOUT IT ===");
}

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
