using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.Features.PayCal.Organisations.StreamOut;

[ExcludeFromCodeCoverage]
[SuppressMessage("ReSharper", "UnusedAutoPropertyAccessor.Global")]
public sealed record StreamOrganisationsRequest
{
    /// <summary>
    ///     The PayCal relative year to retrieve Organisations against.
    ///     Must be a 4 digit year that is valid for the scheme.
    ///     Required.
    /// </summary>
    /// <remarks>
    ///     Organisations returned will have a SubmissionYear equal to RelativeYear.
    /// </remarks>
    public required int? RelativeYear { get; init; }
}