namespace EPR.CommonDataService.Core.Models.Response;

public class PaycalParametersResponse
{
    public bool IsCso { get; set; }

    public char OrganisationSize { get; set; }

    public string OrganisationType { get; set; } = string.Empty;

    public DateTime FirstSubmittedDate { get; set; }

    public DateTime? JoinerDate { get; set; }

    public DateTime? LeaverDate { get; set; }

    public string? LeaverCode { get; set; }
}