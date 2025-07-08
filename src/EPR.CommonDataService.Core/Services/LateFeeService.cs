using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Models.Response;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;

namespace EPR.CommonDataService.Core.Services;

public class LateFeeService(ILogger<LateFeeService> logger, IConfiguration config) : ILateFeeService
{
    private readonly string? _logPrefix = string.IsNullOrWhiteSpace(config["LogPrefix"]) ? "[EPR.CommonDataService]" : config["LogPrefix"];

    public ProducerPaycalParametersResponse UpdateLateFeeFlag(IDictionary<string, string> queryParams, ProducerPaycalParametersResponse producerPaycalParametersResponse)
    {
        var lateFeeSettingsRequest = GetLateFeeSettingsRequest(queryParams, producerPaycalParametersResponse);
        producerPaycalParametersResponse.IsLateFee = DetermineLateFee(producerPaycalParametersResponse, lateFeeSettingsRequest);
        return producerPaycalParametersResponse;
    }

    public IList<CsoPaycalParametersResponse> UpdateLateFeeFlag(IDictionary<string, string> queryParams, IList<CsoPaycalParametersResponse> csoPaycalParametersResponses)    {
        var lateFeeSettingsRequest = GetLateFeeSettingsRequest(queryParams, csoPaycalParametersResponses);
        
        foreach (var item in csoPaycalParametersResponses)
        {
            int year = item.RelevantYear == 2025 ? 2025 : item.RelevantYear - 1;
            int month = item.RelevantYear == 2025 ? lateFeeSettingsRequest.LateFeeCutOffMonth_2025 : lateFeeSettingsRequest.LateFeeCutOffMonth_CS;
            int day = item.RelevantYear == 2025 ? lateFeeSettingsRequest.LateFeeCutOffDay_2025 : lateFeeSettingsRequest.LateFeeCutOffDay_CS;

            var isLateByDate = DetermineLateFee(item, lateFeeSettingsRequest);
            var firstSubmittedLateByDate = DetermineLateFeeByCutoffDate(item.FirstSubmittedOn, year, month, day);

            item.IsLateFee = item.IsNewJoiner ? isLateByDate : firstSubmittedLateByDate;
        }
        return csoPaycalParametersResponses;
    }

    private LateFeeSettingsRequest? GetLateFeeSettingsRequest<T>(IDictionary<string, string> queryParams, T paycalParametersResponse)
    {
        var queryParamsString = JsonConvert.SerializeObject(queryParams);
        var sanitizedQueryParamsString = queryParamsString.Replace("\r", string.Empty).Replace("\n", string.Empty);
        logger.LogInformation("{Logprefix}: LateFeeService - UpdateLateFeeFlag ({Type}) for the given request {QueryParams} & {PaycalParametersResponse}",
            _logPrefix, typeof(T) , sanitizedQueryParamsString, JsonConvert.SerializeObject(paycalParametersResponse));
        return JsonConvert.DeserializeObject<LateFeeSettingsRequest>(queryParamsString);
    }

    private static bool DetermineLateFee(PaycalParametersResponse paycalParametersResponse, LateFeeSettingsRequest? lateFeeSettingsRequest)
    {
        if (lateFeeSettingsRequest is null)
        {
            return false;
        }

        if (paycalParametersResponse.RelevantYear == 2025)
        {
            return DetermineLateFeeByCutoffDate(paycalParametersResponse.EarliestSubmissionDate,
                2025, lateFeeSettingsRequest.LateFeeCutOffMonth_2025, lateFeeSettingsRequest.LateFeeCutOffDay_2025);
        }
        if (paycalParametersResponse.RelevantYear > 2025)
        {
            if (paycalParametersResponse.IsCso)
            {
                var cutoffYear = paycalParametersResponse.RelevantYear - 1;
                return DetermineLateFeeByCutoffDate(paycalParametersResponse.EarliestSubmissionDate, cutoffYear, lateFeeSettingsRequest.LateFeeCutOffMonth_CS, lateFeeSettingsRequest.LateFeeCutOffDay_CS);
            }
            else
            {
                if (paycalParametersResponse.OrganisationSize.Equals("L", StringComparison.OrdinalIgnoreCase))
                {
                    var cutoffYear = paycalParametersResponse.RelevantYear - 1;
                    return DetermineLateFeeByCutoffDate(paycalParametersResponse.EarliestSubmissionDate, cutoffYear, lateFeeSettingsRequest.LateFeeCutOffMonth_LP, lateFeeSettingsRequest.LateFeeCutOffDay_LP);
                }

                if (paycalParametersResponse.OrganisationSize.Equals("S", StringComparison.OrdinalIgnoreCase))
                {
                    return DetermineLateFeeByCutoffDate(paycalParametersResponse.EarliestSubmissionDate, paycalParametersResponse.RelevantYear, lateFeeSettingsRequest.LateFeeCutOffMonth_SP, lateFeeSettingsRequest.LateFeeCutOffDay_SP);
                }
            }
        }

        return false;
    }

    private static bool DetermineLateFeeByCutoffDate(DateTime submittedDate, int year, int month, int day)
    {
//        var submittedDate = paycalParametersResponse.EarliestSubmissionDate;
        return submittedDate.Year > year
            || submittedDate.Month > month
            || (submittedDate.Month == month && submittedDate.Day > day);
    }
}