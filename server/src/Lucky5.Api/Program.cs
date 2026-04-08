using Lucky5.Infrastructure.Services;
using Lucky5.Realtime;
using Lucky5.Realtime.Services;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.Extensions.Diagnostics.HealthChecks;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddEnvironmentVariables();

var portValue = Environment.GetEnvironmentVariable("PORT")
    ?? Environment.GetEnvironmentVariable("WEBSITES_PORT")
    ?? "8080";

if (int.TryParse(portValue, out var port))
{
    builder.WebHost.ConfigureKestrel(options => options.ListenAnyIP(port));
}

if (!builder.Environment.IsDevelopment())
{
    builder.Configuration.AddJsonFile("appsettings.Production.json", optional: true, reloadOnChange: true);
}

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSignalR();
builder.Services.AddLucky5Realtime();
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        var allowedOrigins = builder.Configuration["CORS:ALLOWED_ORIGINS"]
            ?? builder.Configuration["CORS__ALLOWED_ORIGINS"];

        if (!string.IsNullOrWhiteSpace(allowedOrigins))
        {
            var origins = allowedOrigins
                .Split(",", StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);

            if (origins.Length > 0)
            {
                policy.WithOrigins(origins)
                    .AllowAnyHeader()
                    .AllowAnyMethod()
                    .AllowCredentials();
                return;
            }
        }

        policy.AllowAnyOrigin()
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});
builder.Services.AddLucky5Infrastructure(builder.Configuration);

builder.Services.AddHealthChecks()
    .AddCheck("live", () => HealthCheckResult.Healthy("Application is running"));

var app = builder.Build();

app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
});

app.UseStaticFiles();
app.UseRouting();
app.UseCors();
app.MapControllers();
app.MapHub<CarrePokerGameHub>("/CarrePokerGameHub");

app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = check => check.Name == "live"
});
app.MapHealthChecks("/health/ready");
app.MapHealthChecks("/health/simple", new HealthCheckOptions
{
    Predicate = _ => false
});
app.MapHealthChecks("/health/fallback", new HealthCheckOptions
{
    Predicate = _ => false
});

app.Run();
