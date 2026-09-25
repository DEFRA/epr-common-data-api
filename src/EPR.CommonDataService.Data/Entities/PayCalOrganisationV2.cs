#nullable enable
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Data.Entities;

/// <summary>
///     The data source for this entity is the stored procedure <c>sp_GetPaycalOrgData_v2</c>
/// </summary>
[ExcludeFromCodeCoverage]
public record PayCalOrganisationV2
{
    public string? Filename { get; init; }
    public int OrganisationId { get; init; }
    public string? SubsidiaryId { get; init; }
    public string? SubmitterId { get; init; }
    public string? OrganisationName { get; init; }
    public string? TradingName { get; init; }
    public string? StatusCode { get; init; }
    public string? LeaverDate { get; init; }
    public string? JoinerDate { get; init; }
    public int SubmissionPeriodYear { get; init; }
    public string RegulatorStatus { get; init; } = string.Empty;
    public bool IsResubmission { get; init; }
    public DateTime? CreatedAt { get; init; }
}
