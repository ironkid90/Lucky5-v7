namespace Lucky5.Infrastructure.Services;

using System.Net;
using Lucky5.Application.Contracts;
using Lucky5.Application.Interfaces;
using Lucky5.Infrastructure.Data.Repositories;
using Lucky5.Infrastructure.Persistence;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Options;
using StackExchange.Redis;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddLucky5Infrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddSingleton<InMemoryDataStore>();
        services.AddSingleton<IDataStore, InMemoryDataStoreAdapter>();
        
        // Register new persistence services from migration pack
        services.AddOptions<PersistentStateCheckpointOptions>()
            .Bind(configuration.GetSection("Persistence"));
        
        // Register Redis distributed cache
        services.AddStackExchangeRedisCache(options =>
        {
            var connectionString = configuration.GetConnectionString("Redis")
                ?? configuration["LUCKY5_REDIS_CONNECTION"]
                ?? configuration["Redis:ConnectionString"]
                ?? configuration["REDIS:CONNECTION"];

            if (!string.IsNullOrWhiteSpace(connectionString))
            {
                options.Configuration = connectionString;
                
                var configOptions = ConfigurationOptions.Parse(connectionString);
                if (configOptions.EndPoints.Any(endpoint => endpoint is DnsEndPoint dns && dns.Host.EndsWith(".redis.azure.net", StringComparison.OrdinalIgnoreCase)))
                {
                    options.ConfigurationOptions.Ssl = true;
                    options.ConfigurationOptions.ConnectTimeout = 15000;
                    options.ConfigurationOptions.SyncTimeout = 10000;
                    options.ConfigurationOptions.AsyncTimeout = 10000;
                    options.ConfigurationOptions.AbortOnConnectFail = false;
                    options.ConfigurationOptions.ConnectRetry = 3;
                    options.ConfigurationOptions.ReconnectRetryPolicy = new ExponentialRetry(1000);
                }
                else
                {
                    // General Redis configuration
                    options.ConfigurationOptions.ConnectTimeout = 10000;
                    options.ConfigurationOptions.SyncTimeout = 5000;
                    options.ConfigurationOptions.AsyncTimeout = 5000;
                }
            }
            else
            {
                // Fallback to in-memory if Redis not configured
                options.InstanceName = "Lucky5";
            }
        });
        
        services.AddSingleton<IPersistentStateStore, RedisPersistentStateStore>();
        services.AddSingleton<IPersistentStateCoordinator, InMemoryPersistentStateCoordinator>();
        services.AddSingleton<PersistentStateCheckpointService>();
        services.AddHostedService(sp => sp.GetRequiredService<PersistentStateCheckpointService>());
        services.AddHostedService<PersistentStateRecoveryService>();
        
        // Add health checks
        services.AddHealthChecks()
            .AddCheck<PersistentStateHealthCheck>("persistence")
            .AddCheck("basic", () => HealthCheckResult.Healthy("Application is running"));
        services.AddOptions<MachineCacheTtlOptions>()
            .Bind(configuration.GetSection("MachineCache"));
        services.AddSingleton<IMachineStateCache>(sp =>
        {
            var opts = sp.GetRequiredService<IOptions<MachineCacheTtlOptions>>().Value;
            return new InMemoryMachineStateCache(opts);
        });
        services.AddSingleton<ITokenService, SimpleTokenService>();
        services.AddSingleton<IEntropyGenerator, DefaultEntropyGenerator>();
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IGameService, GameService>();
        services.AddScoped<IAdminService, AdminService>();
        services.AddScoped<IGeneralService, GeneralService>();

        return services;
    }
}
