using System.Net.Mime;
using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Api.Features.PayCal.v2.Poms.StreamOut;
using EPR.CommonDataService.Api.Infrastructure;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace EPR.CommonDataService.Api.Features.PayCal.v2.Poms;

[ApiController]
[Route("api/paycal/v2/poms")]
public sealed class PomsController(
    IStreamPomsRequestHandler requestHandler,
    ILogger<PomsController> logger)
    : ControllerBase
{
    /// <summary>
    ///     Streams POMs for the requested relative year as NDJSON.
    ///     Submissions of all regulator statuses are returned.
    /// </summary>
    [HttpGet]
    [EnableRateLimiting(ApiRateLimitOptions.PayCalPomsStreamPolicy)]
    [ProducesResponseType(typeof(void), StatusCodes.Status200OK, "application/x-ndjson")] // typeof(void) as NDJSON stream can't be represented in OpenAPI spec
    [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest, MediaTypeNames.Application.ProblemJson)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public IActionResult StreamOut([FromQuery] StreamPomsRequest request,
        CancellationToken cancellationToken)
    {
        logger.LogInformation("StreamOut: Starting. RelativeYear={RelativeYear} UpdatedSince={UpdatedSince}",
            request.RelativeYear!.Value, request.UpdatedSince);

        return new NdJsonStreamResult<PomResponse>(
            requestHandler.Handle(request, cancellationToken),
            result =>
            {
                var status = result.WasAbortedByClient ? "Aborted by client" : "Completed successfully";

                logger.LogInformation("StreamOut: Finished. Status={Status} RecordsStreamed={RecordsStreamed} Duration={Duration}",
                    status, result.RecordsStreamed, result.Duration.ToString("g"));
            });
    }
}
