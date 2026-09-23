using System.Net.Mime;
using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Api.Features.PayCal.v1.Organisations.StreamOut;
using EPR.CommonDataService.Api.Infrastructure;
using EPR.CommonDataService.Api.Utils;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace EPR.CommonDataService.Api.Features.PayCal.v1.Organisations;

[ApiController]
[Route("api/paycal/organisations")]
public sealed class OrganisationsController(
    IStreamOrganisationsRequestHandler requestHandler,
    ILogger<OrganisationsController> logger)
    : ControllerBase
{
    [HttpGet("stream")]
    [EnableRateLimiting(ApiRateLimitOptions.PayCalOrganisationsStreamPolicy)]
    [ProducesResponseType(typeof(void), StatusCodes.Status200OK, "application/x-ndjson")] // typeof(void) as NDJSON stream can't be represented in OpenAPI spec
    [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest, MediaTypeNames.Application.ProblemJson)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public IActionResult StreamOut([FromQuery] StreamOrganisationsRequest request,
        CancellationToken cancellationToken)
    {
        var relativeYear = request.RelativeYear!.Value;
        var cutOffDate = DateParserUtil.ParseCutoff(request.CutOffDate);
        logger.LogInformation("StreamOut: Starting. RelativeYear={RelativeYear} CutOffDate={CutOffDate}", relativeYear, cutOffDate);

        return new NdJsonStreamResult<OrganisationResponse>(
            requestHandler.Handle(relativeYear, cutOffDate, cancellationToken),
            result =>
            {
                var status = result.WasAbortedByClient ? "Aborted by client" : "Completed successfully";

                logger.LogInformation("StreamOut: Finished. Status={Status} RecordsStreamed={RecordsStreamed} Duration={Duration}",
                    status, result.RecordsStreamed, result.Duration.ToString("g"));
            });
    }
}
