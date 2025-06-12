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
        logger.LogInformation("{Logprefix}: LateFeeService - UpdateLateFeeFlag for the given request {QueryParams} & {PaycalParametersResponses}", 
            _logPrefix, JsonConvert.SerializeObject(queryParams), JsonConvert.SerializeObject(paycalParametersResponses));
        
        try
        {
            foreach (var item in paycalParametersResponses)
            {
                item.IsLateFee = DetermineLateFee(item, queryParams);                
            }
        }
        catch (Exception)
        {
            throw;
        }

        return paycalParametersResponses;
    }

    private static bool DetermineLateFee(PaycalParametersResponse paycalParametersResponse, IDictionary<string, string> queryParams) 
    {

        ////TODO:: Remove the below three lines and implement the business logic
        paycalParametersResponse.IsLateFee = true;
        queryParams["abc"] = "1";
        return false;
    }
}