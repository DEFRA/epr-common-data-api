using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Newtonsoft.Json;
using System.Globalization;

namespace EPR.CommonDataService.Api.Controllers;

[ApiController]
[Route("api/submissions")]
public class SubmissionsController(ISubmissionsService submissionsService, IOptions<ApiConfig> baseApiConfigOptions, ILogger<SubmissionsController> logger, IConfiguration config) : ApiControllerBase(baseApiConfigOptions)
{
    private readonly string? _logPrefix = string.IsNullOrEmpty(config["LogPrefix"]) ? "[EPR.CommonDataService]" : config["LogPrefix"];
    private readonly IOptions<ApiConfig> _baseApiConfigOptions = baseApiConfigOptions;

    [HttpPost("pom/summary")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetPomSubmissionsSummaries(SubmissionsSummariesRequest<RegulatorPomDecision> request)
    {
        logger.LogInformation("{LogPrefix}: SubmissionsController: Api Route 'pom/summary'", _logPrefix);
        logger.LogInformation("{LogPrefix}: SubmissionsController - GetPomSubmissionsSummaries: Get Pom Submissions for given Regulator {PomSubmissions}", _logPrefix, JsonConvert.SerializeObject(request));
        var result = await submissionsService.GetSubmissionPomSummaries(request);

        logger.LogInformation("{LogPrefix}: SubmissionsController - GetPomSubmissionsSummaries: Pom Submissions returned {SubmissionPomSummaries}", _logPrefix, result);
        return Ok(result);
    }

    [HttpPost("registrations/summary")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetRegistrationsSubmissionsSummaries(SubmissionsSummariesRequest<RegulatorRegistrationDecision> request)
    {
        logger.LogInformation("{LogPrefix}: SubmissionsController: Api Route 'registrations/summary'", _logPrefix);
        logger.LogInformation("{LogPrefix}: SubmissionsController - GetRegistrationsSubmissionsSummaries: Get Registration Submissions for given Regulator {RegulatorSubmissions}", _logPrefix, JsonConvert.SerializeObject(request));
        var result = await submissionsService.GetSubmissionRegistrationSummaries(request);

        logger.LogInformation("{LogPrefix}: SubmissionsController - GetRegistrationsSubmissionsSummaries: Registration Submissions returned {SubmissionRegistrationSummaries}", _logPrefix, result);
        return Ok(result);
    }

    /// <summary>
    /// Gets a list of submissions with its aggregated POM data that has been approved after a specific point in time.
    /// </summary>
    /// <param name="approvedAfterDateString">String representing a valid [cref="System.DateTime"] in UTC</param>
    /// <returns>a [cref="System.Collections.Generic.IList&lt;T&gt;"] of [cref="EPR.CommonDataService.Data.Entities.ApprovedSubmissionEntity"]</returns>
    [HttpGet("v1/pom/approved/{approvedAfterDateString}")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status504GatewayTimeout)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> GetApprovedSubmissionsWithAggregatedPomData(string approvedAfterDateString)
    {
        logger.LogInformation("{LogPrefix}: SubmissionsController: Api Route 'v1/pom/approved/{ApprovedAfterDateString}'", _logPrefix, approvedAfterDateString);
        logger.LogInformation("{LogPrefix}: SubmissionsController - GetApprovedSubmissionsWithAggregatedPomData: Get submissions approved after {ApprovedAfterDateString}", _logPrefix, approvedAfterDateString);
        if (!DateTime.TryParse(approvedAfterDateString, CultureInfo.InvariantCulture.DateTimeFormat, DateTimeStyles.AssumeUniversal, out var approvedAfter))
        {
            logger.LogError("{LogPrefix}: SubmissionsController - GetApprovedSubmissionsWithAggregatedPomData: Invalid datetime provided; please make sure it's a valid UTC datetime", _logPrefix);
            ModelState.AddModelError(nameof(approvedAfterDateString), "Invalid datetime provided; please make sure it's a valid UTC datetime");
            return BadRequest(ModelState);
        }

        try
        {
            var approvedSubmissions = await submissionsService.GetApprovedSubmissionsWithAggregatedPomData(approvedAfter, _baseApiConfigOptions.Value.PomDataSubmissionPeriods);

            if (!approvedSubmissions.Any())
            {
                logger.LogError("{LogPrefix}: SubmissionsController - GetApprovedSubmissionsWithAggregatedPomData: The datetime provided did not return any submissions", _logPrefix);
                return NoContent();
            }

            logger.LogInformation("{LogPrefix}: SubmissionsController - GetApprovedSubmissionsWithAggregatedPomData: Approved Submissions returned {ApprovedSubmissions}", _logPrefix, approvedSubmissions);
            return Ok(approvedSubmissions);
        }
        catch (TimeoutException ex)
        {
            logger.LogError(ex, "{LogPrefix}: SubmissionsController - GetApprovedSubmissionsWithAggregatedPomData: Get Approved Submissions request TimedOut - Exception {Ex}", _logPrefix, ex.Message);
            return StatusCode(StatusCodes.Status504GatewayTimeout, ex.Message);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "{LogPrefix}: SubmissionsController - GetApprovedSubmissionsWithAggregatedPomData: Get Approved Submissions request Failed - Exception {Error}", _logPrefix, ex.Message);
            return StatusCode(StatusCodes.Status500InternalServerError, ex.Message);
        }
    }
}