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
        => AddLucky5Infrastructure(services);

    public static IServiceCollection AddLucky5Infrastructure(this IServiceCollection services)
    {
        services.AddSingleton<InMemoryDataStore>();
        services.AddSingleton<IDataStore, InMemoryDataStoreAdapter>();
        services.AddSingleton<IPersistentStateStore>(sp =>
        {
            var cfg = sp.GetRequiredService<IConfiguration>();
            var connectionString = cfg.GetConnectionString("Redis")
                ?? cfg["LUCKY5_REDIS_CONNECTION"]
                ?? cfg["Redis:ConnectionString"];

            if (string.IsNullOrWhiteSpace(connectionString))
            {
                return new NoOpPersistentStateStore();
            }

            var multiplexer = ConnectionMultiplexer.Connect(connectionString);
            return new RedisPersistentStateStore(multiplexer);
        });
        services.AddHostedService<StateRecoveryHostedService>();
        services.AddSingleton<ITokenService, SimpleTokenService>();
        services.AddSingleton<IEntropyGenerator, DefaultEntropyGenerator>();
        services.AddSingleton<IAuthService, AuthService>();
        services.AddSingleton<IGameService, GameService>();
        services.AddSingleton<IAdminService, AdminService>();
        services.AddSingleton<IGeneralService, GeneralService>();
        return services;
    }
}
