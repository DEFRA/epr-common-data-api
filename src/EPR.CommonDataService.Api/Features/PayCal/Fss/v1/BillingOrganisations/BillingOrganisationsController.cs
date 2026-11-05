using System.Net.Mime;
using EPR.CommonDataService.Api.Features.PayCal.Fss.v1.BillingOrganisations.Get;
using Microsoft.AspNetCore.Mvc;

namespace EPR.CommonDataService.Api.Features.PayCal.Fss.v1.BillingOrganisations;

[ApiController]
[Route("api/paycal/fss/v1/billing-organisations")]
public sealed class BillingOrganisationsController(
    IGetBillingOrganisationsRequestHandler requestHandler,
    ILogger<BillingOrganisationsController> logger)
    : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(GetBillingOrganisationsResponse), StatusCodes.Status200OK, MediaTypeNames.Application.Json)]
    [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest, MediaTypeNames.Application.ProblemJson)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> Get([FromQuery] GetBillingOrganisationsRequest request,
        CancellationToken cancellationToken)
    {
        logger.LogInformation("Get: Starting. FinancialYear={FinancialYear} ApprovedAfter={ApprovedAfter}",
            request.FinancialYear, request.ApprovedAfter);

        var response = await requestHandler.Handle(request, cancellationToken);

        logger.LogInformation("Get: Finished. OrganisationsReturned={OrganisationsReturned}",
            response.OrganisationsDetails.Count);

        return Ok(response);
    }
}
