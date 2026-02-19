using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.Features.PayCal.Organisations.StreamOut;

[ExcludeFromCodeCoverage]
[SuppressMessage("ReSharper", "UnusedAutoPropertyAccessor.Global")]
public sealed record OrganisationResponse
{
    public required int SubmissionYear { get; init; }
    public required int OrganisationId { get; init; }
    public required string? SubsidiaryId { get; init; }
    public required string? OrganisationName { get; init; }
    public required string? TradingName { get; init; }
    public required string? StatusCode { get; init; }
    public required string? ErrorCode { get; init; }
    public required string? JoinerDate { get; init; }
    public required string? LeaverDate { get; init; }
    public required string? ObligationStatus { get; init; }
    public required short? NumDaysObligated { get; init; }
    public required string? SubmitterId { get; init; }
}