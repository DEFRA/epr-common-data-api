using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Core.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Newtonsoft.Json;
using System.Globalization;

namespace EPR.CommonDataService.Api.Controllers;

[ApiController]
[Route("api/submissions")]
public class SubmissionsController(ISubmissionsService submissionsService, IOptions<ApiConfig> apiConfig, ILogger<SubmissionsController> logger, IConfiguration config) : ApiControllerBase(apiConfig)
{
    private readonly string? _logPrefix = string.IsNullOrEmpty(config["LogPrefix"]) ? "[EPR.CommonDataService]" : config["LogPrefix"];
    private readonly ApiConfig apiConfig = apiConfig.Value;

    [HttpPost("pom/summary")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetPomSubmissionsSummaries(SubmissionsSummariesRequest<RegulatorPomDecision> request)
    {
        logger.LogInformation("{LogPrefix}: SubmissionsController: Api Route 'pom/summary'", _logPrefix);
        var result = await submissionsService.GetSubmissionPomSummaries(request);

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
        var result = await submissionsService.GetSubmissionRegistrationSummaries(request);

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
    [ProducesResponseType(StatusCodes.Status504GatewayTimeout)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> GetApprovedSubmissionsWithAggregatedPomData(string approvedAfterDateString)
    {
        logger.LogInformation("{LogPrefix}: SubmissionsController: Api Route 'v1/pom/approved/{ApprovedAfterDateString}'", _logPrefix, approvedAfterDateString);

        if (!DateTime.TryParse(approvedAfterDateString, CultureInfo.InvariantCulture.DateTimeFormat, DateTimeStyles.AssumeUniversal, out var approvedAfter))
        {
            logger.LogError("{LogPrefix}: SubmissionsController - GetApprovedSubmissionsWithAggregatedPomData: Invalid datetime provided; please make sure it's a valid UTC datetime", _logPrefix);
            ModelState.AddModelError(nameof(approvedAfterDateString), "Invalid datetime provided; please make sure it's a valid UTC datetime");
            return BadRequest(ModelState);
        }

        try
        {
            var approvedSubmissions = await submissionsService.GetApprovedSubmissionsWithAggregatedPomData(approvedAfter, apiConfig.PomDataSubmissionPeriods, apiConfig.IncludePackagingTypes, apiConfig.IncludePackagingMaterials);

            if (!approvedSubmissions.Any())
            {
                logger.LogError("{LogPrefix}: SubmissionsController - GetApprovedSubmissionsWithAggregatedPomData: The datetime provided did not return any submissions", _logPrefix);
                return NoContent();
            }

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

    [HttpGet("organisation-registrations/{NationId}")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status504GatewayTimeout)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> GetOrganisationRegistrationSubmissions([FromRoute] int NationId, [FromQuery] OrganisationRegistrationFilterRequest filter)
    {
        string filterAsJson = System.Text.Json.JsonSerializer.Serialize(filter);
        logger.LogInformation("{LogPrefix}: SubmissionsController: Api Route 'v1/organisation-registrations/{NationId}'", _logPrefix, NationId);

        try
        {
            if (NationId < 1 || NationId > 4)
            {
                logger.LogError("{LogPrefix}: SubmissionsController - GetOrganisationRegistrationSubmissions: Invalid NationId provided; please make sure it's a valid nationid (1-4) {NationId}", _logPrefix, NationId);
                ModelState.AddModelError(nameof(NationId), "NationID must be a valid and supported nation id");
                return ValidationProblem(ModelState);
            }

            if (!ModelState.IsValid)
            {
                logger.LogError("{LogPrefix}: SubmissionsController - GetOrganisationRegistrationSubmissions: Invalid filter model provided; please make sure page details are provided: {QueryString}", _logPrefix, filterAsJson);
                return ValidationProblem(ModelState);
            }

            var organisationRegistrations = await submissionsService.GetOrganisationRegistrationSubmissionSummaries(NationId, filter);

            if (organisationRegistrations is null || organisationRegistrations.Items.Count == 0)
            {
                logger.LogError("{LogPrefix}: SubmissionsController - GetOrganisationRegistrationSubmissions: The filters provided did not return any submissions. {NationId}/{Querystring}", _logPrefix, NationId, filterAsJson);
                return NoContent();
            }

            return Ok(organisationRegistrations);
        }
        catch (TimeoutException ex)
        {
            logger.LogError(ex, "{LogPrefix}: SubmissionsController - GetOrganisationRegistrationSubmissions: The filters provided caused a timeout exception. {NationId}/{Querystring}: Error: {ErrorMessage}", _logPrefix, NationId, filterAsJson, ex.Message);
            return StatusCode(StatusCodes.Status504GatewayTimeout, ex.Message);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "{LogPrefix}: SubmissionsController - GetOrganisationRegistrationSubmissions: The filters provided caused an exception. {NationId}/{Querystring}: Error: {ErrorMessage}", _logPrefix, NationId, filterAsJson, ex.Message);
            return StatusCode(StatusCodes.Status500InternalServerError, ex.Message);
        }
    }

    [HttpGet("organisation-registration-submission/{SubmissionId}")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status504GatewayTimeout)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> GetOrganisationRegistrationSubmissionDetails([FromRoute] Guid? SubmissionId)
    {
        var sanitisedSubmissionId = SubmissionId?.ToString("D").Replace("\r", string.Empty).Replace("\n", string.Empty);
        logger.LogInformation("{LogPrefix}: SubmissionsController: Api Route 'v1/organisation-registration-submission/{SubmissionId}'", _logPrefix, sanitisedSubmissionId);
        
        try
        {
            if (!SubmissionId.HasValue)
            {
                logger.LogError("{LogPrefix}: SubmissionsController - GetOrganisationRegistrationSubmissionDetails: Invalid SubmissionId provided; please make sure it's a valid Guid", _logPrefix);
                ModelState.AddModelError(nameof(SubmissionId), "SubmissionId must be a valid Guid");
                return ValidationProblem(ModelState);
            }

            var submissiondetails = await submissionsService.GetOrganisationRegistrationSubmissionDetails(new OrganisationRegistrationDetailRequest { SubmissionId = SubmissionId.Value });

            if (submissiondetails is null)
            {
                logger.LogError("{LogPrefix}: SubmissionsController - GetOrganisationRegistrationSubmissionDetails: The SubmissionId provided did not return a submission. {SubmissionId}", _logPrefix, sanitisedSubmissionId);
                return NoContent();
            }

            return Ok(submissiondetails);
        }
        catch (TimeoutException ex)
        {
            logger.LogError(ex, "{LogPrefix}: SubmissionsController - GetOrganisationRegistrationSubmissionDetails: The SubmissionId caused a timeout exception. {SubmissionId}: Error: {ErrorMessage}", _logPrefix, sanitisedSubmissionId, ex.Message);
            return StatusCode(StatusCodes.Status504GatewayTimeout, ex.Message);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "{LogPrefix}: SubmissionsController - GetOrganisationRegistrationSubmissionDetails: The SubmissionId caused an exception. {SubmissionId}: Error: {ErrorMessage}", _logPrefix, sanitisedSubmissionId, ex.Message);
            return StatusCode(StatusCodes.Status500InternalServerError, ex.Message);
        }
    }

    [HttpGet("pom-resubmission-paycal-parameters/{SubmissionId}")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status428PreconditionRequired)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status504GatewayTimeout)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<PomResubmissionPaycalParametersDto>> POMResubmission_PaycalParameters([FromRoute] Guid SubmissionId, [FromQuery] Guid? ComplianceSchemeId)
    {
        var sanitisedSubmissionId = SubmissionId.ToString("D").Replace("\r", string.Empty).Replace("\n", string.Empty);
        var sanitisedComplianceSchemeId = ComplianceSchemeId?.ToString("D").Replace("\r", string.Empty).Replace("\n", string.Empty);

        if (!string.IsNullOrWhiteSpace(sanitisedComplianceSchemeId))
        {
            logger.LogInformation("{LogPrefix}: SubmissionsController - Api Route 'v1/pom-resubmission-paycal-parameters/{SubmissionId}?{ComplianceSchemeId}: Get resubmissions paycal parameters for Submission and ComplianceScheme", _logPrefix, sanitisedSubmissionId, sanitisedComplianceSchemeId);
        }
        else
        {
            logger.LogInformation("{LogPrefix}: SubmissionsController: Api Route 'v1/pom-resubmission-paycal-parameters/{SubmissionId}'", _logPrefix, sanitisedSubmissionId);
        }

        try
        {
            PomResubmissionPaycalParametersDto? dbResult = await submissionsService.GetResubmissionPaycalParameters(sanitisedSubmissionId, sanitisedComplianceSchemeId);

            if (dbResult is null)
            {
                logger.LogError("{LogPrefix}: SubmissionsController - POMResubmission_PaycalParameters: The SubmissionId provided did not return a value. {SubmissionId}", _logPrefix, sanitisedSubmissionId);
                return NoContent();
            }

            if (!dbResult.ReferenceFieldAvailable)
            {
                logger.LogError("The DB for POM Resubmissions isn't updated with the expected Schema changes.");
                return StatusCode(StatusCodes.Status412PreconditionFailed, "Db Schema isn't updated to include PomResubmission ReferenceNumber");
            }
            
            if (string.IsNullOrWhiteSpace(dbResult.Reference))
            {
                logger.LogError("The data for POM Resubmissions {SubmissionId} doesn't have a required reference number.", sanitisedSubmissionId);
                return StatusCode(StatusCodes.Status428PreconditionRequired, "No Reference number found for this submission.  Is Data Syncronised?");
            }

            return Ok(dbResult);
        }
        catch (Exception ex)
        {
            var statusCode = StatusCodes.Status500InternalServerError;
            if (ex is TimeoutException)
            {
                statusCode = StatusCodes.Status504GatewayTimeout;
            }

            logger.LogError(ex, "{LogPrefix}: SubmissionsController - POMResubmission_PaycalParameters: The SubmissionId caused an exception. {SubmissionId}: Error: {ErrorMessage}", _logPrefix, sanitisedSubmissionId, ex.Message);
            return StatusCode(statusCode, ex.Message);
        }
    }

    [HttpGet("is_file_synced_with_cosmos/{FileId}")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status428PreconditionRequired)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status504GatewayTimeout)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<bool>> IsCosmosFileSynchronised([FromRoute] Guid FileId)
    {
        var sanitisedFileId = FileId.ToString("D").Replace("\r", string.Empty).Replace("\n", string.Empty);
        logger.LogInformation("{LogPrefix}: SubmissionsController: Api Route 'v1/is_file_synced_with_cosmos/{FileId}'", _logPrefix, sanitisedFileId);

        try
        {
            bool? dbRet = await submissionsService.IsCosmosDataAvailable(null, sanitisedFileId);

            if (!dbRet.HasValue)
            {
                logger.LogError("{LogPrefix}: SubmissionsController - IsCosmosFileSynchronised: The FileId provided did not return a value. {SubmissionId}", _logPrefix, sanitisedFileId);
                return Ok(false);
            }

            return Ok(dbRet);
        }
        catch (TimeoutException ex)
        {
            logger.LogError(ex, "{LogPrefix}: SubmissionsController - IsCosmosFileSynchronised: The FileId caused a timeout exception. {SubmissionId}: Error: {ErrorMessage}", _logPrefix, sanitisedFileId, ex.Message);
            return StatusCode(StatusCodes.Status504GatewayTimeout, ex.Message);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "{LogPrefix}: SubmissionsController - IsCosmosFileSynchronised: The FileId caused an exception. {FileId}: Error: {ErrorMessage}", _logPrefix, sanitisedFileId, ex.Message);
            return StatusCode(StatusCodes.Status500InternalServerError, ex.Message);
        }
    }

    [HttpGet("is_submission_synced_with_cosmos/{SubmissionId}")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status428PreconditionRequired)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status504GatewayTimeout)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<bool>> IsSubmissionSynchronised([FromRoute] Guid SubmissionId)
    {
        var sanitisedSubmissionId = SubmissionId.ToString("D").Replace("\r", string.Empty).Replace("\n", string.Empty);
        logger.LogInformation("{LogPrefix}: SubmissionsController: Api Route 'v1/is_submission_synced_with_cosmos/{FileId}'", _logPrefix, sanitisedSubmissionId);

        try
        {
            bool? dbRet = await submissionsService.IsCosmosDataAvailable(sanitisedSubmissionId, null);

            if (!dbRet.HasValue)
            {
                logger.LogError("{LogPrefix}: SubmissionsController - IsSubmissionSynchronised: The SubmissionId provided did not return a value. {SubmissionId}", _logPrefix, sanitisedSubmissionId);
                return Ok(false);
            }

            return Ok(dbRet);
        }
        catch (TimeoutException ex)
        {
            logger.LogError(ex, "{LogPrefix}: SubmissionsController - IsSubmissionSynchronised: The SubmissionId caused a timeout exception. {SubmissionId}: Error: {ErrorMessage}", _logPrefix, sanitisedSubmissionId, ex.Message);
            return StatusCode(StatusCodes.Status504GatewayTimeout, ex.Message);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "{LogPrefix}: SubmissionsController - IsSubmissionSynchronised: The SubmissionId caused an exception. {FileId}: Error: {ErrorMessage}", _logPrefix, sanitisedSubmissionId, ex.Message);
            return StatusCode(StatusCodes.Status500InternalServerError, ex.Message);
        }
    }
}
