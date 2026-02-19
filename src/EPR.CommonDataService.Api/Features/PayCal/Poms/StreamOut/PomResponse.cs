using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.Features.PayCal.Poms.StreamOut;

[ExcludeFromCodeCoverage]
[SuppressMessage("ReSharper", "UnusedAutoPropertyAccessor.Global")]
public sealed record PomResponse
{
    public required string SubmissionPeriod { get; init; }
    public required int OrganisationId { get; init; }
    public required string? SubsidiaryId { get; init; }
    public required string? PackagingType { get; init; }
    public required string? PackagingMaterial { get; init; }
    public required double? PackagingMaterialWeight { get; init; }
    public required string? PackagingClass { get; init; }
    public required string? PackagingActivity { get; init; }
    public required string? SubmitterId { get; init; }
}