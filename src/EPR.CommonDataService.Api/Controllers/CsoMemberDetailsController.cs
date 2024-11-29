using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.Controllers;

[ApiController]
[Route("api/cso-member-details")]
public class CsoMemberDetailsController(
    IOptions<ApiConfig> baseApiConfigOptions,
    ICsoMemberDetailsService csoMemberDetailsService)
    : ApiControllerBase(baseApiConfigOptions)
{
    [HttpGet("get-cso-member-details/{organisationId:int}", Name = nameof(GetCsoMemberDetails))]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> GetCsoMemberDetails([FromRoute] int organisationId)
    {
        if (organisationId <= 0)
            return BadRequest("OrganisationId is invalid");

        var result = await csoMemberDetailsService.GetCsoMemberDetails(organisationId);

        return result is null ? NoContent() : Ok(result);
    }
}