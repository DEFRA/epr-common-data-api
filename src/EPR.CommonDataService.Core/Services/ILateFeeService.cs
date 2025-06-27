using EPR.CommonDataService.Core.Models.Response;

namespace EPR.CommonDataService.Core.Services;

public interface ILateFeeService
{
    IList<PaycalParametersResponse> UpdateLateFeeFlag(IDictionary<string, string> queryParams, IList<PaycalParametersResponse> paycalParametersResponses);
}