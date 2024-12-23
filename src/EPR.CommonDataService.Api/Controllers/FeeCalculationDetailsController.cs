using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.Controllers;

[ApiController]
[Route("api/fee-calculation")]
public class FeeCalculationDetailsController(
    IOptions<ApiConfig> baseApiConfigOptions, 
    IFeeCalculationDetailsService feeCalculationDetailsService)
    : ApiControllerBase(baseApiConfigOptions)

{
    [HttpGet("get-fee-calculation-details/{fileId:guid}", Name = nameof(GetFeeCalculationDetails))]
    [Produces("application/json")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> GetFeeCalculationDetails([FromRoute] Guid fileId)
    {
        if (fileId == Guid.Empty)
            return BadRequest("fileId is invalid");

        var result = await feeCalculationDetailsService.GetFeeCalculationDetails(fileId);

        return result is null ? NoContent() : Ok(result);
    }
}