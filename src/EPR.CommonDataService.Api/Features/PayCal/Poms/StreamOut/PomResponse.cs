using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.Features.PayCal.Poms.StreamOut;

[ExcludeFromCodeCoverage]
[SuppressMessage("ReSharper", "UnusedAutoPropertyAccessor.Global")]
public sealed record PomResponse
{
    public string? SubmissionPeriod { get; init; }
    public string? SubmissionPeriodDescription { get; init; }
    public int OrganisationId { get; init; }
    public string? SubsidiaryId { get; init; }
    public string? PackagingType { get; init; }
    public string? PackagingMaterial { get; init; }
    public double? PackagingMaterialWeight { get; init; }
    public string? PackagingClass { get; init; }
    public string? PackagingActivity { get; init; }
    public string? SubmitterId { get; init; }
}