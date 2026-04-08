// Test with infrastructure services - identify problematic component
Console.WriteLine("=== TEST: STARTING ===");

var builder = WebApplication.CreateBuilder(args);
Console.WriteLine("=== TEST: BUILDER CREATED ===");

builder.Services.AddControllers();
Console.WriteLine("=== TEST: CONTROLLERS ADDED ===");

// Add infrastructure services step by step
Console.WriteLine("=== TEST: ADDING INFRASTRUCTURE ===");
try
{
    builder.Services.AddLucky5Infrastructure(builder.Configuration);
    Console.WriteLine("=== TEST: INFRASTRUCTURE ADDED SUCCESSFULLY ===");
}
catch (Exception ex)
{
    Console.WriteLine($"=== TEST: INFRASTRUCTURE FAILED: {ex.Message} ===");
    throw;
}

var app = builder.Build();
Console.WriteLine("=== TEST: APP BUILT ===");

app.MapGet("/", () => "Hello World");
Console.WriteLine("=== TEST: ENDPOINT MAPPED ===");

app.MapGet("/health", () => new { status = "healthy" });
Console.WriteLine("=== TEST: HEALTH ENDPOINT MAPPED ===");

app.MapGet("/health/fallback", () => new { status = "healthy", timestamp = DateTime.UtcNow });
Console.WriteLine("=== TEST: FALLBACK HEALTH ENDPOINT MAPPED ===");

Console.WriteLine("=== TEST: STARTING APP ===");
app.Run();
