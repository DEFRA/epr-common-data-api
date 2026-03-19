using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.Features.PayCal.Poms.StreamOut;

[ExcludeFromCodeCoverage]
[SuppressMessage("ReSharper", "UnusedAutoPropertyAccessor.Global")]
public sealed record StreamPomsRequest
{
    /// <summary>
    ///     The PayCal relative year to retrieve POMs against.
    ///     Must be a 4 digit year that is valid for the scheme.
    ///     Required.
    /// </summary>
    /// <remarks>
    ///     POMs returned will have a SubmissionYear one year PRIOR to RelativeYear.
    /// </remarks>
    public required int? RelativeYear { get; init; }
}