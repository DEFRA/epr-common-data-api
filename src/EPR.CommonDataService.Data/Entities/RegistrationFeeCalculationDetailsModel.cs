using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Data.Entities;

[ExcludeFromCodeCoverage]
public class RegistrationFeeCalculationDetailsModel
{
    public int OrganisationId { get; set; }
    
    public int NumberOfSubsidiaries { get; set; }
    
    public int NumberOfSubsidiariesBeingOnlineMarketPlace { get; set; }

    public int NumberOfSubsidiariesBeingClosedLoopRecycling { get; set; }
    
    public string OrganisationSize { get; set; }
    
    public bool IsOnlineMarketplace  { get; set; }

    public bool IsClosedLoopRecycling { get; set; }

    public bool IsNewJoiner  { get; set; }

    public int NationId { get; set; }
}