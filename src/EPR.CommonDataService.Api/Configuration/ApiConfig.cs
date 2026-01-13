namespace EPR.CommonDataService.Api.Configuration;

public class ApiConfig
{
    public string BaseProblemTypePath { get; set; } = string.Empty;

    public string IncludePackagingTypes { get; set; } = string.Empty;

    public string IncludePackagingMaterials { get; set; } = string.Empty;

    public int PomDataSubmissionPeriodStartMonth { get; set; } = 2;

    public int PomDataSubmissionPeriodStartDay { get; set; } = 1;

}