using Azure.Core;
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
    private readonly string? logPrefix = string.IsNullOrEmpty(config["LogPrefix"]) ? "[EPR.CommonDataService]" : config["LogPrefix"];

    private const string Periods = "P1,P4"; //will be added to config in future story

    [HttpPost("pom/summary")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetPomSubmissionsSummaries(SubmissionsSummariesRequest<RegulatorPomDecision> request)
    {
        logger.LogInformation("{Logprefix}: SubmissionsController: Api Route 'pom/summary'", logPrefix);
        logger.LogInformation("{Logprefix}: SubmissionsController - GetPomSubmissionsSummaries: Get Pom Submissions for given Regulator {PomSubmissions}", logPrefix, JsonConvert.SerializeObject(request));
        var result = await submissionsService.GetSubmissionPomSummaries(request);

        logger.LogInformation("{Logprefix}: SubmissionsController - GetPomSubmissionsSummaries: Pom Submissions returned {SubmissionPomSummaries}", logPrefix, result);
        return Ok(result);
    }

    [HttpPost("registrations/summary")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetRegistrationsSubmissionsSummaries(SubmissionsSummariesRequest<RegulatorRegistrationDecision> request)
    {
        logger.LogInformation("{Logprefix}: SubmissionsController: Api Route 'registrations/summary'", logPrefix);
        logger.LogInformation("{Logprefix}: SubmissionsController - GetRegistrationsSubmissionsSummaries: Get Registration Submissions for given Regulator {RegulatorSubmissions}", logPrefix, JsonConvert.SerializeObject(request));
        var result = await submissionsService.GetSubmissionRegistrationSummaries(request);

        logger.LogInformation("{Logprefix}: SubmissionsController - GetRegistrationsSubmissionsSummaries: Registration Submissions returned {SubmissionRegistrationSummaries}", logPrefix, result);
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
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status504GatewayTimeout)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> GetApprovedSubmissionsWithAggregatedPomData(string approvedAfterDateString)
    {
        logger.LogInformation("{Logprefix}: SubmissionsController: Api Route 'v1/pom/approved/{ApprovedAfterDateString}'", logPrefix, approvedAfterDateString);
        logger.LogInformation("{Logprefix}: SubmissionsController - GetApprovedSubmissionsWithAggregatedPomData: Get submissions approved after {ApprovedAfterDateString}", logPrefix, approvedAfterDateString);
        if (!DateTime.TryParse(approvedAfterDateString, CultureInfo.InvariantCulture.DateTimeFormat, DateTimeStyles.AssumeUniversal, out var approvedAfter))
        {
            logger.LogError("{Logprefix}: SubmissionsController - GetApprovedSubmissionsWithAggregatedPomData: Invalid datetime provided; please make sure it's a valid UTC datetime", logPrefix);
            ModelState.AddModelError(nameof(approvedAfterDateString), "Invalid datetime provided; please make sure it's a valid UTC datetime");
            return BadRequest(ModelState);
        }

        try
        {
            var approvedSubmissions = await submissionsService.GetApprovedSubmissionsWithAggregatedPomData(approvedAfter, Periods);

            if (!approvedSubmissions.Any())
            {
                logger.LogError("{Logprefix}: SubmissionsController - GetApprovedSubmissionsWithAggregatedPomData: The datetime provided did not return any submissions", logPrefix);
                ModelState.AddModelError(nameof(approvedAfterDateString), "The datetime provided did not return any submissions");
                return NotFound(ModelState);
            }

            logger.LogInformation("{Logprefix}: SubmissionsController - GetApprovedSubmissionsWithAggregatedPomData: Approved Submissions returned {ApprovedSubmissions}", logPrefix, approvedSubmissions);
            return Ok(approvedSubmissions);
        }
        catch (TimeoutException ex)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsController - GetApprovedSubmissionsWithAggregatedPomData: Get Approved Submissions request Timedout - Exception {Ex}", logPrefix, ex.Message);
            return StatusCode(StatusCodes.Status504GatewayTimeout, ex.Message);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsController - GetApprovedSubmissionsWithAggregatedPomData: Get Approved Submissions request Failed - Exception {Error}", logPrefix, ex.Message);
            return StatusCode(StatusCodes.Status500InternalServerError, ex.Message);
        }
    }
}