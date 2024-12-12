using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Core.Models.Response;

[ExcludeFromCodeCoverage]
public class GetCsoMemberDetailsResponse
{
    public int MemberId { get; set; }   // OrganisationNumber
    public string MemberType { get; set; } = string.Empty;
    public bool IsOnlineMarketplace { get; set; }
    public bool IsLateFeeApplicable { get; set; } = false;
    public int NumberOfSubsidiaries { get; set; }
    public int NumberOfSubsidiariesBeingOnlineMarketPlace { get; set; }
}