using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Models.Response;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;

namespace EPR.CommonDataService.Core.Services;

public class LateFeeService(ILogger<LateFeeService> logger, IConfiguration config) : ILateFeeService
{
    private readonly string? _logPrefix = string.IsNullOrWhiteSpace(config["LogPrefix"]) ? "[EPR.CommonDataService]" : config["LogPrefix"];
    
    public IList<PaycalParametersResponse> UpdateLateFeeFlag(IDictionary<string, string> queryParams, IList<PaycalParametersResponse> paycalParametersResponses)
    {
        var queryParamsString = JsonConvert.SerializeObject(queryParams);
        logger.LogInformation("{Logprefix}: LateFeeService - UpdateLateFeeFlag for the given request {QueryParams} & {PaycalParametersResponses}", 
            _logPrefix, queryParamsString, JsonConvert.SerializeObject(paycalParametersResponses));
        
        try
        {
            var lateFeeSettingsRequest = JsonConvert.DeserializeObject<LateFeeSettingsRequest>(queryParamsString);
            foreach (var item in paycalParametersResponses)
            {
                item.IsLateFee = DetermineLateFee(item, lateFeeSettingsRequest);
            }
        }
        catch (Exception)
        {
            throw;
        }

        return paycalParametersResponses;
    }

    private static bool DetermineLateFee(PaycalParametersResponse paycalParametersResponse, LateFeeSettingsRequest? lateFeeSettingsRequest) 
    {
        if (lateFeeSettingsRequest is null)
        {
            return false;
        }

        ////TODO:: Remove the below three lines and implement the business logic
        paycalParametersResponse.IsLateFee = true;
        return false;
    }
}