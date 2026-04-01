using Lucky5.Api.Middleware;
using Lucky5.Infrastructure.Data;
using Lucky5.Infrastructure.Services;
using Lucky5.Realtime;
using Lucky5.Realtime.Services;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var port = Environment.GetEnvironmentVariable("PORT")
    ?? Environment.GetEnvironmentVariable("WEBSITES_PORT");
if (!string.IsNullOrWhiteSpace(port))
{
    builder.WebHost.UseUrls($"http://0.0.0.0:{port}");
}

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSignalR();
builder.Services.AddLucky5Infrastructure(builder.Configuration);
builder.Services.AddLucky5Realtime();

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

// Apply EF Core migrations automatically if configured
using (var scope = app.Services.CreateScope())
{
    var dbContext = scope.ServiceProvider.GetService<Lucky5DbContext>();
    if (dbContext != null && dbContext.Database.IsRelational())
    {
        try
        {
            dbContext.Database.Migrate();
        }
        catch (Exception ex)
        {
            // Log the error but don't necessarily crash if it's an in-memory test or similar, 
            // though for production relational DBs this should probably be monitored closely.
            Console.WriteLine($"Error applying migrations: {ex.Message}");
        }
    }
}

app.UseMiddleware<ApiExceptionMiddleware>();
app.UseMiddleware<BearerTokenMiddleware>();
app.UseCors("Lucky5Cors");
app.UseDefaultFiles();
app.UseStaticFiles();
app.MapControllers();
app.MapHub<CarrePokerGameHub>("/CarrePokerGameHub");
app.MapGet("/health/live", () => Results.Ok(new { status = "ok" }));
app.MapGet("/health/ready", () => Results.Ok(new { status = "ready" }));

app.Run();
