using System.Diagnostics.CodeAnalysis;
using Microsoft.AspNetCore.Mvc;

namespace EPR.CommonDataService.Api.Features.Pom;

[ExcludeFromCodeCoverage]
[SuppressMessage("ReSharper", "UnusedAutoPropertyAccessor.Global")]
public sealed record GetPomRequest
{
    /// <summary>
    ///     The organisation's EPR reference number, as it appears in the packaging data CSV.
    ///     Bound from the route rather than the query string, so it is required by construction.
    /// </summary>
    [FromRoute(Name = "organisationId")]
    public int? OrganisationId { get; init; }

    /// <summary>
    ///     Optional PayCal relative year. Omit for every year the organisation appears in.
    /// </summary>
    /// <remarks>
    ///     POMs returned will have a SubmissionYear one year PRIOR to RelativeYear, matching
    ///     the existing PayCal stream.
    /// </remarks>
    public int? RelativeYear { get; init; }

    /// <summary>
    ///     Optional cut-off date. Either yyyy-MM-dd, or ISO 8601 UTC with a literal Z suffix.
    ///     A numeric offset such as +00:00 is not accepted; see DateParserUtil.
    /// </summary>
    public string? CutOffDate { get; init; }
}
