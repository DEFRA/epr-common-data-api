using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Data.Entities;

[ExcludeFromCodeCoverage]
public class FeeCalculationDetailsModel
{
    public int OrganisationId { get; set; }
    
    public int NumberOfSubsidiaries { get; set; }
    
    public int NumberOfSubsidiariesBeingOnlineMarketPlace { get; set; }
    
    public string OrganisationSize { get; set; }
    
    public bool IsOnlineMarketplace  { get; set; }
}