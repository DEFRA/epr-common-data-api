using System.Diagnostics.CodeAnalysis;
using EPR.CommonDataService.Api.Extensions;
using EPR.CommonDataService.Api.HealthChecks;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.FeatureManagement;

namespace EPR.CommonDataService.Api;

[ExcludeFromCodeCoverage]
public static class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        builder.Services
            .AddFeatureManagement();

        builder.Services
            .AddApplicationInsightsTelemetry()
            .RegisterWebComponents(builder.Configuration)
            .RegisterDataComponents(builder.Configuration)
            .AddEndpointsApiExplorer()
            .AddSwaggerGen()
            .AddHealthChecks()
            .AddDbContextCheck<SynapseContext>();

        var app = builder.Build();

        app.UseResponseCompression();
        app.UseRateLimiter();
        app.UseSwagger();
        app.UseSwaggerUI();

        app.UseExceptionHandler("/error");
        app.MapControllers();

        app.MapHealthChecks(
            builder.Configuration.GetValue<string>("HealthCheckPath")!,
            HealthCheckOptionBuilder.Build()).AllowAnonymous();

        app.Run();
    }
}