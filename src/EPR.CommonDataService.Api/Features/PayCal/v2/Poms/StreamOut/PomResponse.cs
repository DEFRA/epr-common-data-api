using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.Features.PayCal.v2.Poms.StreamOut;

[ExcludeFromCodeCoverage]
[SuppressMessage("ReSharper", "UnusedAutoPropertyAccessor.Global")]
public sealed record PomResponse
{
    public required string? Filename { get; init; }
    public required string? SubmissionPeriod { get; init; }
    public required string? SubmissionPeriodDescription { get; init; }
    public required int OrganisationId { get; init; }
    public required string? SubsidiaryId { get; init; }
    public required string? PackagingType { get; init; }
    public required string? PackagingMaterial { get; init; }
    public required string? PackagingMaterialSubtype { get; init; }
    public required double? PackagingMaterialWeight { get; init; }
    public required string? PackagingClass { get; init; }
    public required string? PackagingActivity { get; init; }
    public required string? SubmitterId { get; init; }
    public required string? RamRagRating { get; init; }
    public required DateTimeOffset? CreatedAt { get; init; }
    public required bool IsResubmission { get; init; }
}
