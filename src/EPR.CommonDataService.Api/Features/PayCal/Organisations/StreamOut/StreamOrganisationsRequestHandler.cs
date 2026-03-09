using System.Diagnostics.CodeAnalysis;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace EPR.CommonDataService.Api.Features.PayCal.Organisations.StreamOut;

public interface IStreamOrganisationsRequestHandler
{
    IAsyncEnumerable<OrganisationResponse> Handle(StreamOrganisationsRequest request);
}

[ExcludeFromCodeCoverage(Justification =
    "The stored procedure call is not compatible with SQLite or InMemory databases.")]
public sealed class StreamOrganisationsRequestHandler(SynapseContext dbContext)
    : IStreamOrganisationsRequestHandler
{
    public async IAsyncEnumerable<OrganisationResponse> Handle(StreamOrganisationsRequest request)
    {
        var organisations = dbContext
            .PayCalOrganisations
            .FromSqlInterpolated($"EXEC [dbo].[sp_GetPaycalOrgData] @RelativeYear={request.RelativeYear}")
            .AsNoTracking()
            .WithTimeout(TimeSpan.FromMinutes(10)) // Necessary due to poor db performance
            .AsAsyncEnumerable();

        await foreach (var org in organisations)
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