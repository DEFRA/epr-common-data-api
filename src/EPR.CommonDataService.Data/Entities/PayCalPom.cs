#nullable enable
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Data.Entities;

[ExcludeFromCodeCoverage]
public record PayCalPom
{
    public int? OrganisationId { get; init; }
    public string? SubsidiaryId { get; init; }
    public string? SubmitterId { get; init; }
    public string? SubmissionPeriod { get; init; }
    public string? SubmissionPeriodDescription { get; init; }
    public string? PackagingActivity { get; init; }
    public string? PackagingType { get; init; }
    public string? PackagingClass { get; init; }
    public string? PackagingMaterial { get; init; }
    public double? PackagingMaterialWeight { get; init; }
}