using System.Diagnostics.CodeAnalysis;
using System.IO.Compression;
using System.Text.Json.Serialization;
using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Api.Features.PayCal.Poms.StreamOut;
using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Infrastructure;
using FluentValidation;
using Microsoft.AspNetCore.ResponseCompression;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace EPR.CommonDataService.Api.Extensions;

[ExcludeFromCodeCoverage]
public static class ServiceProviderExtensions
{
    private const string BaseProblemTypePath = "ApiConfig:BaseProblemTypePath";
    public static IServiceCollection RegisterWebComponents(this IServiceCollection services, IConfiguration configuration)
    {
        AddResponseCompression(services);
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
            var accessTokenFile = Environment.GetEnvironmentVariable("AZURE_SQL_ACCESS_TOKEN_FILE");

            if (!string.IsNullOrEmpty(accessTokenFile))
            {
                // This flow is only used when running as a local environment, 
                // AZURE_SQL_ACCESS_TOKEN_FILE is never specified in any real Azure env.
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

            options.AddInterceptors(new TimeoutInterceptor());
        });

        return services;
    }

    private static void AddResponseCompression(IServiceCollection services)
    {
        services.AddResponseCompression(options =>
        {
            options.EnableForHttps = true;
            options.Providers.Add<GzipCompressionProvider>();
            options.MimeTypes = ResponseCompressionDefaults.MimeTypes.Concat(["application/x-ndjson"]);
        });

        services.Configure<GzipCompressionProviderOptions>(options =>
        {
            options.Level = CompressionLevel.Fastest;
        });
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
        services.AddValidatorsFromAssemblyContaining(typeof(Program));
        services.AddScoped<IRegistrationFeeCalculationDetailsService, RegistrationFeeCalculationDetailsService>();
        services.AddScoped<IProducerDetailsService, ProducerDetailsService>();
        services.AddScoped<ISubmissionEventService, SubmissionEventService>();
        services.AddScoped<ISubmissionsService, SubmissionsService>();
        services.AddScoped<IDatabaseTimeoutService, DatabaseTimeoutService>();
        services.AddScoped<IStreamPomsRequestHandler, StreamPomsRequestHandler>();
    }
}