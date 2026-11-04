using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.Features.PayCal.Fss.v1.BillingOrganisations.Get;

[ExcludeFromCodeCoverage]
[SuppressMessage("ReSharper", "UnusedAutoPropertyAccessor.Global")]
public sealed record GetBillingOrganisationsResponse
{
    public required IReadOnlyCollection<BillingOrganisationResponse> OrganisationsDetails { get; init; }
}

[ExcludeFromCodeCoverage]
[SuppressMessage("ReSharper", "UnusedAutoPropertyAccessor.Global")]
public sealed record BillingOrganisationResponse
{
    public required string OrganisationId { get; init; }
    public required string? OrganisationName { get; init; }
    public required string? OrganisationTradingName { get; init; }
    public required string FinancialYear { get; init; }
    public required DateTime ApprovedDate { get; init; }
    public required string? CompaniesHouseNumber { get; init; }
    public required string? HomeNationCode { get; init; }
    public required string? ServiceOfNoticeAddrLine1 { get; init; }
    public required string? ServiceOfNoticeAddrLine2 { get; init; }
    public required string? ServiceOfNoticeAddrCity { get; init; }
    public required string? ServiceOfNoticeAddrCounty { get; init; }
    public required string? ServiceOfNoticeAddrCountry { get; init; }
    public required string? ServiceOfNoticeAddrPostcode { get; init; }
    public required string? ServiceOfNoticeAddrPhoneNumber { get; init; }
    public required string? SoleTraderFirstName { get; init; }
    public required string? SoleTraderLastName { get; init; }
    public required string? SoleTraderPhoneNumber { get; init; }
    public required string? SoleTraderEmail { get; init; }
    public required string? PrimaryContactPersonFirstName { get; init; }
    public required string? PrimaryContactPersonLastName { get; init; }
    public required string? PrimaryContactPersonPhoneNumber { get; init; }
    public required string? PrimaryContactPersonEmail { get; init; }
    public required IReadOnlyList<BillingSubsidiaryResponse> SubsidiaryDetails { get; init; }
}

[ExcludeFromCodeCoverage]
[SuppressMessage("ReSharper", "UnusedAutoPropertyAccessor.Global")]
public sealed record BillingSubsidiaryResponse
{
    public required string SubsidiaryId { get; init; }
    public required string? SubsidiaryName { get; init; }
    public required string? SubsidiaryTradingName { get; init; }
    public required string FinancialYear { get; init; }
    public required DateTime ApprovedDate { get; init; }
}
