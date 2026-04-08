// Ultra-minimal test - no dependencies, no infrastructure
Console.WriteLine("=== TEST: STARTING ===");

var builder = WebApplication.CreateBuilder(args);
Console.WriteLine("=== TEST: BUILDER CREATED ===");

builder.Services.AddControllers();
Console.WriteLine("=== TEST: CONTROLLERS ADDED ===");

var app = builder.Build();
Console.WriteLine("=== TEST: APP BUILT ===");

app.MapGet("/", () => "Hello World");
Console.WriteLine("=== TEST: ENDPOINT MAPPED ===");

app.MapGet("/health", () => new { status = "healthy" });
Console.WriteLine("=== TEST: HEALTH ENDPOINT MAPPED ===");

Console.WriteLine("=== TEST: STARTING APP ===");
app.Run();
