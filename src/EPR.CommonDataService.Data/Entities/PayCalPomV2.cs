#nullable enable
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Data.Entities;

/// <summary>
///     The data source for this entity is the stored procedure <c>sp_GetPaycalPomData_v2</c>
/// </summary>
[ExcludeFromCodeCoverage]
public record PayCalPomV2
{
    public string? Filename { get; init; }
    public int? OrganisationId { get; init; }
    public string? SubsidiaryId { get; init; }
    public string? SubmitterId { get; init; }
    public string? SubmissionPeriod { get; init; }
    public string? SubmissionPeriodDescription { get; init; }
    public string? PackagingActivity { get; init; }
    public string? PackagingType { get; init; }
    public string? PackagingClass { get; init; }
    public string? PackagingMaterial { get; init; }
    public string? PackagingMaterialSubtype { get; init; }
    public double? PackagingMaterialWeight { get; init; }
    public string? RamRagRating { get; init; }
    public bool IsResubmission { get; init; }
    public DateTime? CreatedAt { get; init; }
}
