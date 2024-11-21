using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Data.Entities;

[ExcludeFromCodeCoverage]
public class CsoMemberDetailsModel
{
    public string MemberId { get; set; }    // OrganisationNumber
    public string MemberType { get; set; }
    public bool IsOnlineMarketplace { get; set; }
    public int NumberOfSubsidiaries { get; set; }
    public int NumberOfSubsidiariesBeingOnlineMarketPlace { get; set; }
}