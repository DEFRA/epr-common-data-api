using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Core.Models.Response;

[ExcludeFromCodeCoverage]
public class FeeCalculationDetails
{
    public string OrganisationId { get; set; } = string.Empty;
    public int NumberOfSubsidiaries { get; set; }
    public int NumberOfSubsidiariesBeingOnlineMarketPlace { get; set; }
    public string OrganisationSize { get; set; } = string.Empty;
    public bool IsOnlineMarketplace  { get; set; }
}
