using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Core.Models.Requests;

[ExcludeFromCodeCoverage]
public class SubmissionsSummariesRequest<T>
{
    public Guid UserId { get; set; }
    
    public T[]? DecisionsDelta { get; set; }
    
    public string? OrganisationName { get; set; }
    
    public string? OrganisationReference { get; set; }
    
    public string? OrganisationType { get; set; }
    
    public string? Statuses { get; set; }

    public string? SubmissionYears { get; set; }

    public string? SubmissionPeriods { get; set; }
    
    public int PageSize { get; set; }
    
    public int PageNumber { get; set; }
}