using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.Controllers;

[ApiController]
[Route("api/registration-fee-calculation-details")]
public class RegistrationFeeCalculationDetailsController(
    IOptions<ApiConfig> baseApiConfigOptions, 
    IRegistrationFeeCalculationDetailsService registrationFeeCalculationDetailsService)
    : ApiControllerBase(baseApiConfigOptions)

{
    [HttpGet("get-registration-fee-calculation-details/{fileId:guid}", Name = nameof(GetRegistrationFeeCalculationDetails))]
    [Produces("application/json")]
    [ProducesResponseType(typeof(UpdatedProducersResponseModel[]), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> GetRegistrationFeeCalculationDetails([FromRoute] Guid fileId)
    {
        if (fileId == Guid.Empty)
            return BadRequest("fileId is invalid");

        var result = await registrationFeeCalculationDetailsService.GetRegistrationFeeCalculationDetails(fileId);

        return result is null ? NoContent() : Ok(result);
    }
}