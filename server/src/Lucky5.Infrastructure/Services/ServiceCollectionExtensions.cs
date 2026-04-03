namespace Lucky5.Infrastructure.Services;

using Lucky5.Application.Contracts;
using Lucky5.Application.Interfaces;
using Lucky5.Infrastructure.Data;
using Lucky5.Infrastructure.Data.Repositories;
using Microsoft.EntityFrameworkCore;
using Lucky5.Infrastructure.Data.Repositories;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddLucky5Infrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("DefaultConnection");
        if (string.IsNullOrEmpty(connectionString))
        {
            // Fallback to in-memory store if no connection string is configured
            services.AddSingleton<IDataStore, InMemoryDataStoreAdapter>();
            services.AddSingleton<InMemoryDataStore>(); // The actual state container
        }
        else
        {
            services.AddDbContext<Lucky5DbContext>(options =>
                options.UseNpgsql(connectionString));
            services.AddScoped<IDataStore, EfCoreDataStore>();
        }

        => AddLucky5Infrastructure(services);

    public static IServiceCollection AddLucky5Infrastructure(this IServiceCollection services)
    {
        services.AddSingleton<InMemoryDataStore>();
        services.AddSingleton<IDataStore, InMemoryDataStoreAdapter>();
        services.AddSingleton<ITokenService, SimpleTokenService>();
        services.AddSingleton<IEntropyGenerator, DefaultEntropyGenerator>();
        services.AddScoped<IAuthService, AuthService>(); // Changed to Scoped to match DbContext lifecycle
        services.AddScoped<IGameService, GameService>(); // Changed to Scoped
        services.AddScoped<IAdminService, AdminService>(); // Changed to Scoped
        services.AddScoped<IGeneralService, GeneralService>(); // Changed to Scoped
        
        return services;
    }
}
