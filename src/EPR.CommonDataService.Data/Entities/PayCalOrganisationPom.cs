#nullable enable
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Data.Entities;

/// <summary>
///     A POM row for a single organisation, as returned by cdp.sp_GetPaycalPomDataByOrganisation.
///     Same shape as <see cref="PayCalPom" /> plus organisation name and reporting nation, which the
///     PayCal stream does not carry.
/// </summary>
[ExcludeFromCodeCoverage]
public record PayCalOrganisationPom
{
    public int? OrganisationId { get; init; }
    public string? OrganisationName { get; init; }
    public string? SubsidiaryId { get; init; }
    public string? SubmitterId { get; init; }
    public string? SubmissionPeriod { get; init; }
    public string? SubmissionPeriodDescription { get; init; }
    public string? PackagingActivity { get; init; }
    public string? PackagingType { get; init; }
    public string? PackagingClass { get; init; }
    public string? PackagingMaterial { get; init; }
    public string? PackagingMaterialSubtype { get; init; }
    public string? FromCountry { get; init; }
    public double? PackagingMaterialWeight { get; init; }
    public string? RamRagRating { get; init; }
}
