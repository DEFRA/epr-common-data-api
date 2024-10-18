using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Api.Extensions;
using EPR.CommonDataService.Core.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.Controllers;

[ApiController]
[Route("api/company-details")]
public class CompanyDetailsController(
    IOptions<ApiConfig> baseApiConfigOptions,
    ICompanyDetailsService companyDetailsService)
    : ApiControllerBase(baseApiConfigOptions)

{
    [HttpGet("get-online-market-place-flag")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> GetOnlineMarketplaceFlag(string organisationId)
    {
        if (organisationId.IsInvalidGuid(out var organisationIdGuid))
            return BadRequest("OrganisationId is invalid");

        var result = await companyDetailsService.GetOnlineMarketplaceFlag(organisationIdGuid);

        return result is null ? NoContent() : Ok(result);
    }
}