using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Api.Extensions;
using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.Controllers;

public class ProducerPropertiesController(
    IOptions<ApiConfig> baseApiConfigOptions, 
    IProducerPropertiesService producerPropertiesService)
    : ApiControllerBase(baseApiConfigOptions)

{
    [HttpGet("get-producer-size")]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetProducerSize(GetProducerSizeRequest request)
    {
        if (request == null || request.OrganisationId.IsInvalidValidGuid())
            return BadRequest("OrganisationId is invalid");

        var result = await producerPropertiesService.GetProducerSize(request);

        return result is null ? NotFound() : Ok(result);
    }
}