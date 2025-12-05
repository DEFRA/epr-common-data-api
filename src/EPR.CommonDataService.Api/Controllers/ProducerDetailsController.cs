using System.Diagnostics.CodeAnalysis;
using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Entities;
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
    [ProducesResponseType(typeof(List<UpdatedProducersResponseModel>), StatusCodes.Status200OK)]
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
    
    [HttpGet("updated-producers/", Name = nameof(GetUpdatedProducersV2))]
    [Produces("application/json")]
    [ProducesResponseType(typeof(List<UpdatedProducersResponseModelV2>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> GetUpdatedProducersV2(DateTime from, DateTime to)
    {
        var result = await producerDetailsService.GetUpdatedProducersV2(from, to);

        if (result == null || result.Count == 0)
        {
            return NoContent();
        }

        return Ok(result);
    }
}