namespace Lucky5.Infrastructure.Services;

using Lucky5.Application.Contracts;
using Lucky5.Application.Interfaces;
using Lucky5.Infrastructure.Data.Repositories;
using Microsoft.Extensions.DependencyInjection;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddLucky5Infrastructure(this IServiceCollection services)
    {
        services.AddSingleton<InMemoryDataStore>();
        services.AddSingleton<IDataStore, InMemoryDataStoreAdapter>();
        services.AddSingleton<ITokenService, SimpleTokenService>();
        services.AddSingleton<IEntropyGenerator, DefaultEntropyGenerator>();
        services.AddSingleton<IAuthService, AuthService>();
        services.AddSingleton<IGameService, GameServiceSimple>();
        services.AddSingleton<IAdminService, AdminService>();
        services.AddSingleton<IGeneralService, GeneralService>();
        return services;
    }
}
