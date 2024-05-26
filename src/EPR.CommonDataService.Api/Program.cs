using EPR.CommonDataService.Api.Extensions;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.IdentityModel.Logging;

var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddApplicationInsightsTelemetry()
    .RegisterWebComponents(builder.Configuration)
    .RegisterDataComponents(builder.Configuration)
    .AddEndpointsApiExplorer()
    .AddSwaggerGen()
    .AddHealthChecks()
    .AddDbContextCheck<SynapseContext>();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    IdentityModelEventSource.ShowPII = true;
    app.UseDeveloperExceptionPage();
    app.UseSwagger();
    app.UseSwaggerUI();
}
else
{
    app.UseExceptionHandler("/error");
}

app.MapControllers();
app.MapHealthChecks("/admin/health").AllowAnonymous();

app.Run();
