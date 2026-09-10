using System.Diagnostics;
using System.Net.Mime;
using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Api.Controllers;
using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.Features.PayCal.Poms.ByOrganisation;

/// <summary>
///     PayCal POM data for a single organisation.
///
///     The stream at /api/paycal/poms/stream returns every producer for a whole year as NDJSON,
///     because that is what a billing run needs. A consumer that wants one organisation has to pull
///     the national extract and discard almost all of it.
///
///     This endpoint answers the same question for one organisation, which makes it a small bounded
///     result rather than a stream, so it returns a plain JSON array and needs no rate limit policy.
///     It is backed by cdp.sp_GetPaycalPomDataByOrganisation, a copy of sp_GetPaycalPomData with an
///     organisation filter and an optional year. Every PayCal business filter is unchanged.
///
///     A separate controller rather than an action on PomsController, so that the existing
///     controller and its tests are untouched.
/// </summary>
[ApiController]
[Route("api/paycal/poms")]
public sealed class PomsByOrganisationController(
    IGetOrganisationPomsRequestHandler requestHandler,
    IValidator<GetOrganisationPomsRequest> requestValidator,
    IOptions<ApiConfig> apiConfig,
    ILogger<PomsByOrganisationController> logger)
    : ApiControllerBase(apiConfig)
{
    [HttpGet("by-organisation")]
    [ProducesResponseType(typeof(IEnumerable<OrganisationPomResponse>), StatusCodes.Status200OK, MediaTypeNames.Application.Json)]
    [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest, MediaTypeNames.Application.ProblemJson)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> GetByOrganisation(
        [FromQuery] GetOrganisationPomsRequest request,
        CancellationToken cancellationToken)
    {
        // Reject if request is invalid as the underlying DB calls are expensive
        var validationResult = await requestValidator.ValidateAsync(request, cancellationToken);

        if (!validationResult.IsValid)
        {
            logger.LogInformation("GetByOrganisation: Invalid request. Errors={Errors}",
                string.Join("; ", validationResult.Errors.Select(e => $"{e.PropertyName}: {e.ErrorMessage}")));

            foreach (var error in validationResult.Errors)
                ModelState.AddModelError(error.PropertyName, error.ErrorMessage);

            return ValidationProblem();
        }

        var organisationId = request.OrganisationId!.Value;
        var cutOffDate = DateParserUtil.ParseCutoff(request.CutOffDate);

        logger.LogInformation(
            "GetByOrganisation: Starting. OrganisationId={OrganisationId} RelativeYear={RelativeYear} CutOffDate={CutOffDate}",
            organisationId, request.RelativeYear, cutOffDate);

        var stopwatch = Stopwatch.StartNew();
        var rows = await requestHandler.Handle(organisationId, request.RelativeYear, cutOffDate, cancellationToken);
        stopwatch.Stop();

        logger.LogInformation("GetByOrganisation: Finished. OrganisationId={OrganisationId} RecordsReturned={RecordsReturned} Duration={Duration}",
            organisationId, rows.Count, stopwatch.Elapsed.ToString("g"));

        // An organisation that reported nothing is a 200 with an empty array, not a 404. It is a
        // real organisation with no data, and a consumer should not have to treat that as an error.
        return Ok(rows);
    }
}
