using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.Controllers;

[ApiController]
[Route("api/submission-events")]
public class SubmissionEventsController : ApiControllerBase
{
    private readonly ISubmissionEventService _submissionEventService;

    public SubmissionEventsController(ISubmissionEventService submissionEventService,
        IOptions<ApiConfig> baseApiConfigOptions) : base(baseApiConfigOptions)
    {
        _submissionEventService = submissionEventService;
    }
    
    [HttpGet("v1/get-last-sync-time")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetLastSyncTime()
    {
        var result = await _submissionEventService.GetLastSyncTimeAsync();

        return Ok(result);
    }
}