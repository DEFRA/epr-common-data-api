using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Core.Models.Response;

[ExcludeFromCodeCoverage]
public class GetCsoMemberDetailsResponse
{
    public string MemberId { get; set; } = string.Empty;    // OrganisationNumber
    public string MemberType { get; set; } = string.Empty;
    public bool IsOnlineMarketplace { get; set; }
    public bool IsLateFeeApplicable { get; set; } = false;
    public int NumberOfSubsidiaries { get; set; }
    public int NumberOfSubsidiariesBeingOnlineMarketPlace { get; set; }
}