namespace EPR.CommonDataService.Api.Configuration;

public class ApiConfig
{
    public string BaseProblemTypePath { get; set; } = string.Empty;

    public string PomDataSubmissionPeriods { get; set; } = string.Empty;

	public string ExcludePackagingTypes { get; set; } = string.Empty;

    public string IncludePackagingMaterials { get; set; } = string.Empty;
}