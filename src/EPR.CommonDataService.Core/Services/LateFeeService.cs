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
        var sanitizedQueryParamsString = queryParamsString.Replace("\r", string.Empty).Replace("\n", string.Empty);
        logger.LogInformation("{Logprefix}: LateFeeService - UpdateLateFeeFlag for the given request {QueryParams} & {PaycalParametersResponses}",
            _logPrefix, sanitizedQueryParamsString, JsonConvert.SerializeObject(paycalParametersResponses));

        var lateFeeSettingsRequest = JsonConvert.DeserializeObject<LateFeeSettingsRequest>(queryParamsString);
        foreach (var item in paycalParametersResponses)
        {
            item.IsLateFee = DetermineLateFee(item, lateFeeSettingsRequest);
        }

        return paycalParametersResponses;
    }

    private static bool DetermineLateFee(PaycalParametersResponse paycalParametersResponse, LateFeeSettingsRequest? lateFeeSettingsRequest)
    {
        if (lateFeeSettingsRequest is null)
        {
            return false;
        }

        if (paycalParametersResponse.RelevantYear == 2025)
        {
            return DetermineLateFee(paycalParametersResponse,
                2025, lateFeeSettingsRequest.LateFeeCutOffMonth_2025, lateFeeSettingsRequest.LateFeeCutOffDay_2025);
        }
        if (paycalParametersResponse.RelevantYear > 2025)
        {
            if (paycalParametersResponse.IsCso)
            {
                var cutoffYear = paycalParametersResponse.RelevantYear - 1;
                return DetermineLateFee(paycalParametersResponse, cutoffYear, lateFeeSettingsRequest.LateFeeCutOffMonth_CS, lateFeeSettingsRequest.LateFeeCutOffDay_CS);
            }
            else
            {
                if (paycalParametersResponse.OrganisationSize.Equals("Large", StringComparison.OrdinalIgnoreCase))
                {
                    var cutoffYear = paycalParametersResponse.RelevantYear - 1;
                    return DetermineLateFee(paycalParametersResponse, cutoffYear, lateFeeSettingsRequest.LateFeeCutOffMonth_LP, lateFeeSettingsRequest.LateFeeCutOffDay_LP);
                }

                if (paycalParametersResponse.OrganisationSize.Equals("Small", StringComparison.OrdinalIgnoreCase))
                {
                    return DetermineLateFee(paycalParametersResponse, paycalParametersResponse.RelevantYear, lateFeeSettingsRequest.LateFeeCutOffMonth_SP, lateFeeSettingsRequest.LateFeeCutOffDay_SP);
                }
            }
        }

        return false;
    }

    private static bool DetermineLateFee(PaycalParametersResponse paycalParametersResponse, int year, int month, int day)
    {
        var submittedDate = paycalParametersResponse.FirstSubmittedDate;
        return submittedDate.Year > year
            || submittedDate.Month > month
            || (submittedDate.Month == month && submittedDate.Day > day);
    }
}