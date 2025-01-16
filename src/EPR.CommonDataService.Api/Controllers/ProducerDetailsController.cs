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
    [HttpGet("get-updated-producers/", Name = nameof(GetUpdatedProducers))]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> GetUpdatedProducers(DateTime from, DateTime to)
    {
        var result = await producerDetailsService.GetUpdatedProducers(from, to);

        return result is null ? NoContent() : Ok(result);
    }
}