using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.Controllers;

[ApiController]
[Route("api/producer-details")]
public class ProducerDetailsController(
    IOptions<ApiConfig> baseApiConfigOptions,
    IProducerDetailsService producerDetailsService)
    : ApiControllerBase(baseApiConfigOptions)

{
    [HttpGet("get-producer-details/{organisationId:int}", Name = nameof(GetProducerDetails))]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> GetProducerDetails([FromRoute] int organisationId)
    {
        if (organisationId <= 0)
            return BadRequest("OrganisationId is invalid");

        var result = await producerDetailsService.GetProducerDetails(organisationId);

        return result is null ? NoContent() : Ok(result);
    }

    [HttpGet("get-updated-producers/", Name = nameof(GetUpdatedProducers))]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> GetUpdatedProducers(DateTime from, DateTime to)
    {
        var result = await producerDetailsService.GetUpdatedProducers(from, to);

        if (result == null || result.Count == 0)
        {
            return NoContent();
        }

        return Ok(result);
    }
}