using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.Controllers;

[ApiController]
[Route("api/submission-events")]
public class SubmissionEventsController(
    ISubmissionEventService submissionEventService,
    IOptions<ApiConfig> baseApiConfigOptions)
    : ApiControllerBase(baseApiConfigOptions)
{
    [HttpGet("get-last-sync-time")]
    [Produces("application/json")]
    [ProducesResponseType(typeof(UpdatedProducersResponseModel), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetLastSyncTime()
    {
        var result = await submissionEventService.GetLastSyncTimeAsync();

        return Ok(result);
    }
}