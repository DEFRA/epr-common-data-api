using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Core.Models.Response;

[ExcludeFromCodeCoverage]
public class RegistrationFeeCalculationDetails
{
    public string OrganisationId { get; set; } = string.Empty;
    
    public int NumberOfSubsidiaries { get; set; }
    
    public int NumberOfSubsidiariesBeingOnlineMarketPlace { get; set; }
    
    public string OrganisationSize { get; set; } = string.Empty;
    
    public bool IsOnlineMarketplace  { get; set; }

    public bool IsNewJoiner  { get; set; }

    public int NationId { get; set; }
}
