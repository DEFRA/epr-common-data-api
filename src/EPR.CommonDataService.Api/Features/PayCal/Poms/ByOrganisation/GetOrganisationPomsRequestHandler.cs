using System.Diagnostics.CodeAnalysis;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace EPR.CommonDataService.Api.Features.PayCal.Poms.ByOrganisation;

public interface IGetOrganisationPomsRequestHandler
{
    Task<IReadOnlyCollection<OrganisationPomResponse>> Handle(
        int organisationId, int? relativeYear, DateTimeOffset? cutOffDate, CancellationToken cancellationToken);
}

[ExcludeFromCodeCoverage(Justification =
    "The stored procedure call is not compatible with SQLite or InMemory databases.")]
public sealed class GetOrganisationPomsRequestHandler(SynapseContext dbContext)
    : IGetOrganisationPomsRequestHandler
{
    public async Task<IReadOnlyCollection<OrganisationPomResponse>> Handle(
        int organisationId, int? relativeYear, DateTimeOffset? cutOffDate, CancellationToken cancellationToken)
    {
        // All three parameters are passed explicitly, including the nulls. A dedicated SQL pool runs
        // on the PDW engine, which does not allow default parameter values, so the procedure cannot
        // declare any and every call has to supply all of them.
        var rows = await dbContext
            .PayCalOrganisationPoms
            .FromSqlInterpolated(
                $"EXEC [cdp].[sp_GetPaycalPomDataByOrganisation] @RelativeYear={relativeYear}, @OrganisationId={organisationId}, @CutOffDate={cutOffDate}")
            .AsNoTracking()
            .WithTimeout(TimeSpan.FromMinutes(10)) // Necessary due to poor db performance
            .ToListAsync(cancellationToken);

        return rows
            .Select(pom => new OrganisationPomResponse
            {
                OrganisationId = pom.OrganisationId!.Value,
                OrganisationName = pom.OrganisationName,
                SubmissionPeriod = pom.SubmissionPeriod,
                SubmissionPeriodDescription = pom.SubmissionPeriodDescription,
                SubsidiaryId = pom.SubsidiaryId,
                PackagingType = pom.PackagingType,
                PackagingMaterial = pom.PackagingMaterial,
                PackagingMaterialSubtype = pom.PackagingMaterialSubtype,
                FromCountry = pom.FromCountry,
                PackagingMaterialWeight = pom.PackagingMaterialWeight,
                PackagingClass = pom.PackagingClass,
                PackagingActivity = pom.PackagingActivity,
                RamRagRating = pom.RamRagRating,
                SubmitterId = pom.SubmitterId
            })
            .ToList();
    }
}
