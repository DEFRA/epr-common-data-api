using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Api.Extensions;
using EPR.CommonDataService.Core.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.Controllers;

[ApiController]
[Route("api/producer-properties")]
public class ProducerPropertiesController(
    IOptions<ApiConfig> baseApiConfigOptions, 
    IProducerPropertiesService producerPropertiesService)
    : ApiControllerBase(baseApiConfigOptions)

{
    [HttpGet("get-producer-size")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> GetProducerSize(string organisationId)
    {
        if (organisationId.IsInvalidGuid(out var organisationIdGuid))
            return BadRequest("OrganisationId is invalid");

        var result = await producerPropertiesService.GetProducerSize(organisationIdGuid);

        return result is null ? NoContent() : Ok(result);
    }
}