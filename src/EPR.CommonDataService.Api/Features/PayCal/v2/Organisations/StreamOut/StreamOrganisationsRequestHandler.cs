using System.Diagnostics.CodeAnalysis;
using System.Runtime.CompilerServices;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace EPR.CommonDataService.Api.Features.PayCal.v2.Organisations.StreamOut;

public interface IStreamOrganisationsRequestHandler
{
    IAsyncEnumerable<OrganisationResponse> Handle(StreamOrganisationsRequest request, CancellationToken cancellationToken);
}

[ExcludeFromCodeCoverage(Justification =
    "The stored procedure call is not compatible with SQLite or InMemory databases.")]
public sealed class StreamOrganisationsRequestHandler(SynapseContext dbContext)
    : IStreamOrganisationsRequestHandler
{
    public async IAsyncEnumerable<OrganisationResponse> Handle(
        StreamOrganisationsRequest request,
        [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        var organisations = dbContext
            .PayCalOrganisationsV2
            .FromSqlInterpolated($"EXEC [dbo].[sp_GetPaycalOrgData_v2] @RelativeYear={request.RelativeYear}")
            .AsNoTracking()
            .WithTimeout(TimeSpan.FromMinutes(10)) // Necessary due to poor db performance
            .AsAsyncEnumerable()
            .WithCancellation(cancellationToken);

        await foreach (var org in organisations)
        {
            yield return new OrganisationResponse
            {
                Filename = org.Filename,
                OrganisationId = org.OrganisationId,
                SubsidiaryId = org.SubsidiaryId,
                OrganisationName = org.OrganisationName!,
                TradingName = org.TradingName,
                JoinerDate = org.JoinerDate,
                StatusCode = org.StatusCode,
                LeaverDate = org.LeaverDate,
                SubmitterId = org.SubmitterId,
                SubmissionPeriodYear = org.SubmissionPeriodYear,
                RegulatorStatus = org.RegulatorStatus,
                IsResubmission = org.IsResubmission,
                CreatedAt = org.CreatedAt is { } value ? new DateTimeOffset(value, TimeSpan.Zero) : null
            };
        }
    }
}
