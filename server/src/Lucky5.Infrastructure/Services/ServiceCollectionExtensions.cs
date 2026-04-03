namespace Lucky5.Infrastructure.Services;

using Lucky5.Application.Contracts;
using Lucky5.Application.Interfaces;
using Lucky5.Infrastructure.Data.Repositories;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using StackExchange.Redis;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddLucky5Infrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddSingleton<InMemoryDataStore>();
        services.AddSingleton<IDataStore, InMemoryDataStoreAdapter>();
        services.AddSingleton<IPersistentStateStore>(_ =>
        {
            var connectionString = configuration.GetConnectionString("Redis")
                ?? configuration["LUCKY5_REDIS_CONNECTION"]
                ?? configuration["Redis:ConnectionString"]
                ?? configuration["REDIS:CONNECTION"];

            if (string.IsNullOrWhiteSpace(connectionString))
            {
                return new NoOpPersistentStateStore();
            }

            var options = ConfigurationOptions.Parse(connectionString);
            options.AbortOnConnectFail = false;
            if (options.EndPoints.Any(endpoint => endpoint is DnsEndPoint dns && dns.Host.EndsWith(".redis.azure.net", StringComparison.OrdinalIgnoreCase)))
            {
                options.Ssl = true;
            }

            var multiplexer = ConnectionMultiplexer.Connect(options);
            return new RedisPersistentStateStore(multiplexer);
        });
        services.AddHostedService<StateRecoveryHostedService>();
        services.AddHostedService<StateCheckpointHostedService>();
        services.AddSingleton<ITokenService, SimpleTokenService>();
        services.AddSingleton<IEntropyGenerator, DefaultEntropyGenerator>();
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IGameService, GameService>();
        services.AddScoped<IAdminService, AdminService>();
        services.AddScoped<IGeneralService, GeneralService>();

        return services;
    }
}
