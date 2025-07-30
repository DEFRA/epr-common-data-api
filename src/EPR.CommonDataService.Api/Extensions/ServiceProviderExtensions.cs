using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;
using System.Text.Json.Serialization;

namespace EPR.CommonDataService.Api.Extensions;

[System.Diagnostics.CodeAnalysis.ExcludeFromCodeCoverageAttribute]
public static class ServiceProviderExtensions
{
    private const int NOMINAL_MAX_CMD_TIMEOUT = 3600; // seconds
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
        string? connectionString = configuration.GetConnectionString("SynapseDatabase");
        int timeoutInSeconds = extractTimeoutFromConnStr(connectionString) ?? configuration.GetValue<int?>("CommandTimeoutSeconds") ?? NOMINAL_MAX_CMD_TIMEOUT;

        services.AddDbContext<SynapseContext>(options => options.UseSqlServer(connectionString,
                                                         sqloptions => sqloptions.CommandTimeout(timeoutInSeconds)));
        return services;
    }

    private static int? extractTimeoutFromConnStr(string? connectionString)
    {
        static int? extractCommandTimeout(string? connStr)
        {
            const string key = "Command Timeout=";

            if (string.IsNullOrWhiteSpace(connStr))
                return null;

            // Find the key (case-insensitive)
            int idx = connStr.IndexOf(key, StringComparison.OrdinalIgnoreCase);
            if (idx < 0)
                return null;

            // Move to the start of the numeric value
            idx += key.Length;

            // Find end of value (the next semicolon), or use end-of-string
            int endIdx = connStr.IndexOf(';', idx);
            string numStr = (endIdx >= 0)
                ? connStr.Substring(idx, endIdx - idx)
                : connStr.Substring(idx);

            // Try to parse and return, else null
            return int.TryParse(numStr, out var n) ? (int?)n : null;
        }

        return extractCommandTimeout(connectionString);
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