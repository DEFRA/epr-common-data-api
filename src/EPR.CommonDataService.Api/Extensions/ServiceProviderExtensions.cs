using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;
using System.Text.Json.Serialization;
using Microsoft.Data.SqlClient;

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
        services.AddDbContext<SynapseContext>(options =>
        {
            var connectionString = configuration.GetConnectionString("SynapseDatabase");
            var accessToken = Environment.GetEnvironmentVariable("AZURE_SQL_ACCESS_TOKEN");
            var accessTokenFile = Environment.GetEnvironmentVariable("AZURE_SQL_ACCESS_TOKEN_FILE");

            if (!string.IsNullOrEmpty(accessToken))
            {
                var connectionStringBuilder = new SqlConnectionStringBuilder(connectionString);
                connectionStringBuilder.Remove("Authentication");
        
                var sqlConnection = new SqlConnection(connectionStringBuilder.ConnectionString);
                
                sqlConnection.AccessToken = accessToken;
                
                options.UseSqlServer(sqlConnection);
            }
            else if (!string.IsNullOrEmpty(accessTokenFile))
            {
                var connectionStringBuilder = new SqlConnectionStringBuilder(connectionString);
                connectionStringBuilder.Remove("Authentication");
        
                var sqlConnection = new SqlConnection(connectionStringBuilder.ConnectionString);
                
                sqlConnection.AccessToken = File.ReadAllText(accessTokenFile).Trim();
                
                options.UseSqlServer(sqlConnection);
            }
            else
            {
                options.UseSqlServer(connectionString);                
            }
        });

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