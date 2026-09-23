using System.Net.Mime;
using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Api.Features.PayCal.Poms.StreamOut;
using EPR.CommonDataService.Api.Infrastructure;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace EPR.CommonDataService.Api.Features.PayCal.Poms;

[ApiController]
[Route("api/paycal/poms")]
public sealed class PomsController(
    IStreamPomsRequestHandler requestHandler,
    ILogger<PomsController> logger)
    : ControllerBase
{
    [HttpGet("stream")]
    [EnableRateLimiting(ApiRateLimitOptions.PayCalPomsStreamPolicy)]
    [ProducesResponseType(typeof(void), StatusCodes.Status200OK, "application/x-ndjson")] // typeof(void) as NDJSON stream can't be represented in OpenAPI spec
    [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest, MediaTypeNames.Application.ProblemJson)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public IActionResult StreamOut([FromQuery] StreamPomsRequest request,
        CancellationToken cancellationToken)
    {
        var relativeYear = request.RelativeYear!.Value;
        var cutOffDate = DateParserUtil.ParseCutoff(request.CutOffDate);
        logger.LogInformation("StreamOut: Starting. RelativeYear={RelativeYear} CutOffDate={CutOffDate}", relativeYear, cutOffDate);

        return new NdJsonStreamResult<PomResponse>(
            requestHandler.Handle(relativeYear, cutOffDate),
            result =>
            {
                var status = result.WasAbortedByClient ? "Aborted by client" : "Completed successfully";

                logger.LogInformation("StreamOut: Finished. Status={Status} RecordsStreamed={RecordsStreamed} Duration={Duration}",
                    status, result.RecordsStreamed, result.Duration.ToString("g"));
            });
    }
}
