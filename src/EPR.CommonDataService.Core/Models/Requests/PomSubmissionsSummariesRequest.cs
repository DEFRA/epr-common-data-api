namespace EPR.CommonDataService.Core.Models.Requests;

public class PomSubmissionsSummariesRequest
{
    public Guid UserId { get; set; }
    
    public RegulatorPomDecision[]? DecisionsDelta { get; set; }
    
    public string? OrganisationName { get; set; }
    
    public string? OrganisationReference { get; set; }
    
    public string? OrganisationType { get; set; }
    
    public string? Statuses { get; set; }
    
    public int PageSize { get; set; }
    
    public int PageNumber { get; set; }
}