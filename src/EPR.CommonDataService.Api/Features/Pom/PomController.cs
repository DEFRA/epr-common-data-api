using System.Diagnostics;
using System.Net.Mime;
using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Api.Controllers;
using EPR.CommonDataService.Api.Features.PayCal;
using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.Features.Pom;

/// <summary>
///     POM data for a single organisation.
///
///     The stream at /api/paycal/poms/stream returns every producer for a whole year as NDJSON,
///     because that is what a billing run needs. A consumer that wants one organisation has to pull
///     the national extract and discard almost all of it. This answers the same question for one
///     organisation, which makes it a small bounded result rather than a stream, so it returns a
///     plain JSON array and needs no rate limit policy.
///
///     IMPORTANT: this returns the chargeable subset of an organisation's POM data, not all of it.
///     It is backed by cdp.sp_GetPaycalPomDataByOrganisation, a copy of the PayCal procedure with an
///     organisation filter and an optional year added. Every one of that procedure's business filters
///     still applies: large producers only, packaging types HH, CW and PB plus HDC glass, no exports,
///     accepted submissions only, and only organisations that reported both halves of the year.
///
///     A separate controller rather than an action on PomsController, so that the existing controller
///     and its tests are untouched.
/// </summary>
[ApiController]
[Route("api/pom")]
public sealed class PomController(
    IGetPomRequestHandler requestHandler,
    IValidator<GetPomRequest> requestValidator,
    IOptions<ApiConfig> apiConfig,
    ILogger<PomController> logger)
    : ApiControllerBase(apiConfig)
{
    [HttpGet("{organisationId:int}")]
    [ProducesResponseType(typeof(IEnumerable<OrganisationPomResponse>), StatusCodes.Status200OK, MediaTypeNames.Application.Json)]
    [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest, MediaTypeNames.Application.ProblemJson)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> Get(
        [FromRoute] int organisationId,
        [FromQuery] GetPomRequest query,
        CancellationToken cancellationToken)
    {
        // The organisation comes from the path and the filters from the query string, matching how
        // the rest of this API is routed. They are combined so one validator covers the whole request.
        var request = query with { OrganisationId = organisationId };

        var problem = await ValidateAsync(
            requestValidator, request, logger, "GetPom", cancellationToken);

        if (problem is not null) return problem;

        var cutOffDate = DateParserUtil.ParseCutoff(request.CutOffDate);

        logger.LogInformation(
            "GetPom: Starting. OrganisationId={OrganisationId} RelativeYear={RelativeYear} CutOffDate={CutOffDate}",
            organisationId, request.RelativeYear, cutOffDate);

        var stopwatch = Stopwatch.StartNew();
        var rows = await requestHandler.Handle(organisationId, request.RelativeYear, cutOffDate, cancellationToken);
        stopwatch.Stop();

        logger.LogInformation("GetPom: Finished. OrganisationId={OrganisationId} RecordsReturned={RecordsReturned} Duration={Duration}",
            organisationId, rows.Count, stopwatch.Elapsed.ToString("g"));

        // An organisation that reported nothing is a 200 with an empty array, not a 404. It is a
        // real organisation with no data, and a consumer should not have to treat that as an error.
        return Ok(rows);
    }
}
