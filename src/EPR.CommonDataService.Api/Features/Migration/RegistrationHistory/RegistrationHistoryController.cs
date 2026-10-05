using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Api.Controllers;
using EPR.CommonDataService.Api.Infrastructure;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Microsoft.FeatureManagement.Mvc;

namespace EPR.CommonDataService.Api.Features.Migration.RegistrationHistory;

[ApiController]
[Route("api/migration/registration-history")]
[FeatureGate(FeatureName)]
public sealed class RegistrationHistoryController(
    IStreamRegistrationHistoryRequestHandler requestHandler,
    IOptions<ApiConfig> apiConfig,
    ILogger<RegistrationHistoryController> logger)
    : ApiControllerBase(apiConfig)
{
    public const string FeatureName = "RegistrationMigrationEndpoint";

    [HttpGet]
    [ProducesResponseType(typeof(void), StatusCodes.Status200OK, "application/x-ndjson")] // typeof(void) as NDJSON stream can't be represented in OpenAPI spec
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public IActionResult StreamOut()
    {
        logger.LogInformation("RegistrationHistory StreamOut: Starting.");

        return new NdJsonStreamResult<RegistrationHistoryResponse>(
            requestHandler.Handle(),
            result =>
            {
                var status = result.WasAbortedByClient ? "Aborted by client" : "Completed successfully";

                logger.LogInformation("RegistrationHistory StreamOut: Finished. Status={Status} RecordsStreamed={RecordsStreamed} Duration={Duration}",
                    status, result.RecordsStreamed, result.Duration.ToString("g"));
            });
    }
}
