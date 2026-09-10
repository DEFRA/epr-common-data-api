using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.Features.PayCal.Poms.ByOrganisation;

[ExcludeFromCodeCoverage]
[SuppressMessage("ReSharper", "UnusedAutoPropertyAccessor.Global")]
public sealed record GetOrganisationPomsRequest
{
    /// <summary>
    ///     The organisation's EPR reference number, as it appears in the packaging data CSV.
    ///     Required. This endpoint exists to serve one organisation at a time.
    /// </summary>
    public required int? OrganisationId { get; init; }

    /// <summary>
    ///     Optional PayCal relative year. Omit for every year the organisation appears in.
    /// </summary>
    /// <remarks>
    ///     POMs returned will have a SubmissionYear one year PRIOR to RelativeYear, matching
    ///     the existing PayCal stream.
    /// </remarks>
    public int? RelativeYear { get; init; }

    /// <summary>Optional cut-off date, in yyyy-MM-dd or ISO 8601 form.</summary>
    public string? CutOffDate { get; init; }
}
