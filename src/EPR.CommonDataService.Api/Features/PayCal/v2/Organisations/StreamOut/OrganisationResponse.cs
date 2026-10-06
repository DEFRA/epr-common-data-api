using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.Features.PayCal.v2.Organisations.StreamOut;

[ExcludeFromCodeCoverage]
[SuppressMessage("ReSharper", "UnusedAutoPropertyAccessor.Global")]
public sealed record OrganisationResponse
{
    public required string? Filename { get; init; }
    public required int OrganisationId { get; init; }
    public required string? SubsidiaryId { get; init; }
    public required string? SubmitterId { get; init; }
    public required string? OrganisationName { get; init; }
    public required string? TradingName { get; init; }
    public required string? StatusCode { get; init; }
    public required string? LeaverDate { get; init; }
    public required string? JoinerDate { get; init; }
    public required int SubmissionPeriodYear { get; init; }
    public required string RegulatorStatus { get; init; }
    public required DateTimeOffset? CreatedAt { get; init; }
    public required bool IsResubmission { get; init; }
}
