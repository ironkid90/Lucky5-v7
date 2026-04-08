using Lucky5.Api.Middleware;
using Lucky5.Infrastructure.Services;
using Lucky5.Realtime;
using Lucky5.Realtime.Services;
using Microsoft.AspNetCore.HttpOverrides;

var builder = WebApplication.CreateBuilder(args);

// Ensure appsettings.json can be loaded properly
builder.Configuration.AddEnvironmentVariables();

var port = Environment.GetEnvironmentVariable("PORT")
    ?? Environment.GetEnvironmentVariable("WEBSITES_PORT");
if (!string.IsNullOrWhiteSpace(port))
{
    builder.WebHost.UseUrls($"http://0.0.0.0:{port}");
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

app.UseForwardedHeaders();
app.UseMiddleware<ApiExceptionMiddleware>();
app.UseMiddleware<BearerTokenMiddleware>();
app.UseCors("Lucky5Cors");
app.UseDefaultFiles();
app.UseStaticFiles();
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

app.Run();
