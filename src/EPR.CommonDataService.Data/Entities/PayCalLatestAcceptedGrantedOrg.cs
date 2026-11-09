#nullable enable
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Data.Entities;

/// <summary>
///     The data source for this entity is the stored procedure <c>GetLatestAcceptedGrantedOrgData</c>
/// </summary>
[ExcludeFromCodeCoverage]
public record PayCalLatestAcceptedGrantedOrg
{
    public int? OrganisationId { get; init; }
    public string? SubsidiaryId { get; init; }
    public string? OrganisationName { get; init; }
    public string? TradingName { get; init; }
    public int RelativeYear { get; init; }
    public string? CompaniesHouseNumber { get; init; }
    public string? HomeNationCode { get; init; }
    public string? ServiceOfNoticeAddrLine1 { get; init; }
    public string? ServiceOfNoticeAddrLine2 { get; init; }
    public string? ServiceOfNoticeAddrCity { get; init; }
    public string? ServiceOfNoticeAddrCounty { get; init; }
    public string? ServiceOfNoticeAddrCountry { get; init; }
    public string? ServiceOfNoticeAddrPostcode { get; init; }
    public string? ServiceOfNoticeAddrPhoneNumber { get; init; }
    public string? SoleTraderFirstName { get; init; }
    public string? SoleTraderLastName { get; init; }
    public string? SoleTraderPhoneNumber { get; init; }
    public string? SoleTraderEmail { get; init; }
    public string? PrimaryContactPersonFirstName { get; init; }
    public string? PrimaryContactPersonLastName { get; init; }
    public string? PrimaryContactPersonPhoneNumber { get; init; }
    public string? PrimaryContactPersonEmail { get; init; }
    public string DecisionDate { get; init; } = string.Empty;
}
