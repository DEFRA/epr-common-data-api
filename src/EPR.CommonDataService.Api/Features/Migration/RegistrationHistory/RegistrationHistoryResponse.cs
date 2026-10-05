using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.Features.Migration.RegistrationHistory;

[ExcludeFromCodeCoverage]
[SuppressMessage("ReSharper", "UnusedAutoPropertyAccessor.Global")]
public sealed record RegistrationHistoryResponse
{
    public string? SubmissionId { get; init; }
    public string? FileId { get; init; }
    public string? BlobName { get; init; }
    public string? OrganisationId { get; init; }
    public string? ComplianceSchemeId { get; init; }
    public string? SubmissionPeriod { get; init; }
    public string? RegistrationJourney { get; init; }
    public string? RegulatorNation { get; init; }
    public string? Roles { get; init; }
    public string? EventType { get; init; }
    public int EventTypeOrder { get; init; }
    public DateTime? ReplayTs { get; init; }
    public DateTime? EventDate { get; init; }
    public string? ApplicationReferenceNumber { get; init; }
    public string? Decision { get; init; }
}
