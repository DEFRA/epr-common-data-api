namespace EPR.CommonDataService.Core.Models.Requests;

public class RegulatorRegistrationDecision
{
    public Guid FileId { get; set; }
    public string Decision { get; set; }
    public string? Comments { get; set; }
}