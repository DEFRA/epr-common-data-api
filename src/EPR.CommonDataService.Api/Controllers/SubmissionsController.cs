using System.Globalization;
using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.Controllers;

[ApiController]
[Route("api/submissions")]
public class SubmissionsController : ApiControllerBase
{
    private readonly ISubmissionsService _submissionsService;

    public SubmissionsController(ISubmissionsService submissionsService,
        IOptions<ApiConfig> baseApiConfigOptions) : base(baseApiConfigOptions)
    {
        _submissionsService = submissionsService;
    }

    [HttpPost("pom/summary")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetPomSubmissionsSummaries(SubmissionsSummariesRequest<RegulatorPomDecision> request)
    {
        var result = await _submissionsService.GetSubmissionPomSummaries(request);

        return Ok(result);
    }

    [HttpPost("registrations/summary")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetRegistrationsSubmissionsSummaries(SubmissionsSummariesRequest<RegulatorRegistrationDecision> request)
    {
        var result = await _submissionsService.GetSubmissionRegistrationSummaries(request);

        return Ok(result);
    }

    /// <summary>
    /// Gets a list of submissions that have been approved after a specific point in time.
    /// </summary>
    /// <param name="approvedAfterDateString">String representing a valid [cref="System.DateTime"] in UTC</param>
    /// <returns>a [cref="System.Collections.Generic.IList&lt;T&gt;"] of [cref="EPR.CommonDataService.Data.Entities.ApprovedSubmissionEntity"]</returns>
    [HttpGet("pom/approved/{approvedAfterDateString}")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetApprovedSubmissions(string approvedAfterDateString)
    {
        // ask question about date times in the db, are they UTC?
        if (DateTime.TryParse(approvedAfterDateString, CultureInfo.InvariantCulture.DateTimeFormat, DateTimeStyles.AssumeUniversal, out var approvedAfter))
        {
            var approvedSubmissions = await _submissionsService.GetApprovedSubmissions(approvedAfter);

            return Ok(approvedSubmissions);
        }
        else
        {
            ModelState.AddModelError(nameof(approvedAfterDateString), "Invalid datetime provided; please make sure it's a valid UTC datetime");

            return BadRequest(ModelState);
        }
    }

    [HttpGet("pom/data/{submissionIdString}")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetAggregatedPomData(string submissionIdString)
    {
        if (Guid.TryParse(submissionIdString, out var submissionId))
        {
            var aggregatedPomData = await _submissionsService.GetAggregatedPomData(submissionId);

            return Ok(aggregatedPomData);
        }
        else
        {
            ModelState.AddModelError(nameof(submissionIdString), "Invalid GUID provided; please make sure it's a correctly formatted GUID");

            return BadRequest(ModelState);
        }
    }
}