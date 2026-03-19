using System.Net.Mime;
using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Api.Controllers;
using EPR.CommonDataService.Api.Features.PayCal.Organisations.StreamOut;
using EPR.CommonDataService.Api.Infrastructure;
using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.Features.PayCal.Organisations;

[ApiController]
[Route("api/paycal/organisations")]
public sealed class OrganisationsController(
    IStreamOrganisationsRequestHandler requestHandler,
    IValidator<StreamOrganisationsRequest> requestValidator,
    IOptions<ApiConfig> apiConfig,
    ILogger<OrganisationsController> logger)
    : ApiControllerBase(apiConfig)
{
    [HttpGet("stream")]
    [EnableRateLimiting(ApiRateLimitOptions.PayCalOrganisationsStreamPolicy)]
    [ProducesResponseType(typeof(void), StatusCodes.Status200OK, "application/x-ndjson")] // typeof(void) as NDJSON stream can't be represented in OpenAPI spec
    [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest, MediaTypeNames.Application.ProblemJson)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> StreamOut([FromQuery] StreamOrganisationsRequest request,
        CancellationToken cancellationToken)
    {
        // Reject if request is invalid as the underlying DB calls are expensive
        var validationResult = await requestValidator.ValidateAsync(request, cancellationToken);

        if (!validationResult.IsValid)
        {
            logger.LogInformation("StreamOut: Invalid request. Errors={Errors}",
                string.Join("; ", validationResult.Errors.Select(e => $"{e.PropertyName}: {e.ErrorMessage}")));

            foreach (var error in validationResult.Errors)
                ModelState.AddModelError(error.PropertyName, error.ErrorMessage);

            return ValidationProblem();
        }

        logger.LogInformation("StreamOut: Starting. Request={Request}", request);

        return new NdJsonStreamResult<OrganisationResponse>(
            requestHandler.Handle(request),
            result =>
            {
                var status = result.WasAbortedByClient ? "Aborted by client" : "Completed successfully";

                logger.LogInformation("StreamOut: Finished. Status={Status} RecordsStreamed={RecordsStreamed} Duration={Duration}",
                    status, result.RecordsStreamed, result.Duration.ToString("g"));
            });
    }
}