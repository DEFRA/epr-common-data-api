using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;
using System.Text.Json.Serialization;

namespace EPR.CommonDataService.Api.Extensions;

[System.Diagnostics.CodeAnalysis.ExcludeFromCodeCoverageAttribute]
public static class ServiceProviderExtensions
{
    private const string BaseProblemTypePath = "ApiConfig:BaseProblemTypePath";
    public static IServiceCollection RegisterWebComponents(this IServiceCollection services, IConfiguration configuration)
    {
        AddControllers(services, configuration);
        ConfigureOptions(services, configuration);
        RegisterServices(services);

        return services;
    }

    public static IServiceCollection RegisterDataComponents(this IServiceCollection services, IConfiguration configuration)
    {
        int timeoutInSeconds = configuration.GetValue<int?>("CommandTimeoutSeconds") ?? 4000;

        services.AddDbContext<SynapseContext>(options => options.UseSqlServer(configuration.GetConnectionString("SynapseDatabase"),
                                                         sqloptions => sqloptions.CommandTimeout(timeoutInSeconds)));
        return services;
    }

    private static void AddControllers(IServiceCollection services, IConfiguration configuration)
    {
        var baseProblemPath = configuration.GetValue<string>(BaseProblemTypePath);

        services
            .AddControllers()
            .AddJsonOptions(options => options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()))
            .ConfigureApiBehaviorOptions(options =>
            {
                options.ClientErrorMapping[StatusCodes.Status400BadRequest].Link =
                    $"{baseProblemPath}validation";

                options.ClientErrorMapping[StatusCodes.Status409Conflict].Link =
                    $"{baseProblemPath}conflict";

                options.ClientErrorMapping[StatusCodes.Status404NotFound].Link =
                    $"{baseProblemPath}not-found";
            });
    }

    private static void ConfigureOptions(IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<ApiConfig>(configuration.GetSection(nameof(ApiConfig)));
    }

    private static void RegisterServices(IServiceCollection services)
    {
        services.AddScoped<IRegistrationFeeCalculationDetailsService, RegistrationFeeCalculationDetailsService>();
        services.AddScoped<IProducerDetailsService, ProducerDetailsService>();
        services.AddScoped<ISubmissionEventService, SubmissionEventService>();
        services.AddScoped<ISubmissionsService, SubmissionsService>();
        services.AddScoped<IDatabaseTimeoutService, DatabaseTimeoutService>();
    }
}