using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.Features.PayCal.Fss.v1.BillingOrganisations.Get;

[ExcludeFromCodeCoverage]
[SuppressMessage("ReSharper", "UnusedAutoPropertyAccessor.Global")]
public sealed record GetBillingOrganisationsRequest
{
    /// <summary>
    ///     The financial year to retrieve organisations for, in the format YYYY-YY e.g. 2025-26.
    ///     Optional.
    /// </summary>
    public string? FinancialYear { get; init; }

    /// <summary>
    ///     Only return organisations with a decision approved on or after this date.
    ///     Optional.
    /// </summary>
    public DateTimeOffset? ApprovedAfter { get; init; }
}
