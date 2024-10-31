namespace EPR.CommonDataService.Core.Models.Requests;

public class RegulatorPomDecision
{
    public Guid FileId { get; set; }
    public string Decision { get; set; } = string.Empty;
    public string? Comments { get; set; }
    public bool IsResubmissionRequired { get; set;  }
}