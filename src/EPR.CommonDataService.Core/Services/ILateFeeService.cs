using EPR.CommonDataService.Core.Models.Response;

namespace EPR.CommonDataService.Core.Services;

public interface ILateFeeService
{
    ProducerPaycalParametersResponse UpdateLateFeeFlag(IDictionary<string, string> queryParams, ProducerPaycalParametersResponse producerPaycalParametersResponse);
    
    IList<CsoPaycalParametersResponse> UpdateLateFeeFlag(IDictionary<string, string> queryParams, IList<CsoPaycalParametersResponse> csoPaycalParametersResponses);
}