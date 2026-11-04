using System.Diagnostics.CodeAnalysis;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace EPR.CommonDataService.Api.Features.PayCal.Fss.v1.BillingOrganisations.Get;

public interface IGetBillingOrganisationsRequestHandler
{
    Task<GetBillingOrganisationsResponse> Handle(GetBillingOrganisationsRequest request, CancellationToken cancellationToken);
}

[ExcludeFromCodeCoverage(Justification =
    "The stored procedure call is not compatible with SQLite or InMemory databases.")]
public sealed class GetBillingOrganisationsRequestHandler(
    SynapseContext dbContext,
    ILogger<GetBillingOrganisationsRequestHandler> logger)
    : IGetBillingOrganisationsRequestHandler
{
    public async Task<GetBillingOrganisationsResponse> Handle(
        GetBillingOrganisationsRequest request,
        CancellationToken cancellationToken)
    {
        var approvedAfter = request.ApprovedAfter?.UtcDateTime;
        var relativeYear = request.FinancialYear is { } financialYear
            ? FinancialYear.ToRelativeYear(financialYear)
            : (int?)null;

        var rows = await dbContext
            .PayCalLatestAcceptedGrantedOrgs
            .FromSqlInterpolated($"EXEC [dbo].[GetLatestAcceptedGrantedOrgData] @approvedAfter={approvedAfter}, @relativeYear={relativeYear}")
            .AsNoTracking()
            .ToListAsync(cancellationToken);

        return new GetBillingOrganisationsResponse
        {
            OrganisationsDetails = BillingOrganisationsBuilder.Build(rows, logger)
        };
    }
}
