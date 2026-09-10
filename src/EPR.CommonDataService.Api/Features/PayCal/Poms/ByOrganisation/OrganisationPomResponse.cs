using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.Features.PayCal.Poms.ByOrganisation;

/// <summary>
///     One reported packaging row for a single organisation.
/// </summary>
[ExcludeFromCodeCoverage]
[SuppressMessage("ReSharper", "UnusedAutoPropertyAccessor.Global")]
public sealed record OrganisationPomResponse
{
    public int OrganisationId { get; init; }
    public string? OrganisationName { get; init; }
    public string? SubmissionPeriod { get; init; }
    public string? SubmissionPeriodDescription { get; init; }
    public string? SubsidiaryId { get; init; }
    public string? PackagingType { get; init; }
    public string? PackagingMaterial { get; init; }
    public string? PackagingMaterialSubtype { get; init; }
    public string? FromCountry { get; init; }
    public double? PackagingMaterialWeight { get; init; }
    public string? PackagingClass { get; init; }
    public string? PackagingActivity { get; init; }
    public string? SubmitterId { get; init; }
    public string? RamRagRating { get; init; }
}
