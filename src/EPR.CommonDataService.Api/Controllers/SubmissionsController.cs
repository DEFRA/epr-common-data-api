using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using System.Globalization;

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
    /// Gets a list of submissions with its aggregated POM data that has been approved after a specific point in time.
    /// </summary>
    /// <param name="approvedAfterDateString">String representing a valid [cref="System.DateTime"] in UTC</param>
    /// <returns>a [cref="System.Collections.Generic.IList&lt;T&gt;"] of [cref="EPR.CommonDataService.Data.Entities.ApprovedSubmissionEntity"]</returns>
    [HttpGet("pom/approved/{approvedAfterDateString}")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status504GatewayTimeout)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> GetApprovedSubmissionsWithAggregatedPomData(string approvedAfterDateString)
    {
        if (!DateTime.TryParse(approvedAfterDateString, CultureInfo.InvariantCulture.DateTimeFormat, DateTimeStyles.AssumeUniversal, out var approvedAfter))
        {
            ModelState.AddModelError(nameof(approvedAfterDateString), "Invalid datetime provided; please make sure it's a valid UTC datetime");

            return BadRequest(ModelState);
        }

        try
        {
            var approvedSubmissions = await _submissionsService.GetApprovedSubmissionsWithAggregatedPomData(approvedAfter);

            if (!approvedSubmissions.Any())
            {
                ModelState.AddModelError(nameof(approvedAfterDateString), "The datetime provided did not return any submissions");
                return NotFound(ModelState);
            }

            return Ok(approvedSubmissions);
        }
        catch (TimeoutException ex)
        {
            return StatusCode(StatusCodes.Status504GatewayTimeout, ex.Message);
        }
        catch (Exception ex)
        {
            return StatusCode(StatusCodes.Status500InternalServerError, ex.Message);
        }
    }
}