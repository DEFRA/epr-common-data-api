using System.Diagnostics.CodeAnalysis;
using System.Runtime.CompilerServices;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace EPR.CommonDataService.Api.Features.PayCal.v1.Organisations.StreamOut;

public interface IStreamOrganisationsRequestHandler
{
    IAsyncEnumerable<OrganisationResponse> Handle(int relativeYear, DateTimeOffset? cutOffDate, CancellationToken cancellationToken);
}

[ExcludeFromCodeCoverage(Justification =
    "The stored procedure call is not compatible with SQLite or InMemory databases.")]
public sealed class StreamOrganisationsRequestHandler(SynapseContext dbContext)
    : IStreamOrganisationsRequestHandler
{
    public async IAsyncEnumerable<OrganisationResponse> Handle(
        int relativeYear,
        DateTimeOffset? cutOffDate,
        [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        var organisations = dbContext
            .PayCalOrganisations
            .FromSqlInterpolated($"EXEC [dbo].[sp_GetPaycalOrgData] @RelativeYear={relativeYear}, @CutOffDate={cutOffDate}")
            .AsNoTracking()
            .WithTimeout(TimeSpan.FromMinutes(10)) // Necessary due to poor db performance
            .AsAsyncEnumerable()
            .WithCancellation(cancellationToken);

        await foreach (var org in organisations)
        {
            yield return new OrganisationResponse
            {
                OrganisationId = org.OrganisationId!.Value,
                SubsidiaryId = org.SubsidiaryId,
                OrganisationName = org.OrganisationName!,
                TradingName = org.TradingName,
                StatusCode = org.StatusCode,
                ErrorCode = org.ErrorCode,
                JoinerDate = org.JoinerDate,
                LeaverDate = org.LeaverDate,
                ObligationStatus = org.ObligationStatus,
                NumDaysObligated = org.NumDaysObligated,
                SubmitterId = org.SubmitterId,
                HasH1 = org.HasH1,
                HasH2 = org.HasH2,
            };
        }
    }
}
