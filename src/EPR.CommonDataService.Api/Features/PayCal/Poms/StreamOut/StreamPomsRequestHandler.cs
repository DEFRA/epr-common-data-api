using System.Diagnostics.CodeAnalysis;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace EPR.CommonDataService.Api.Features.PayCal.Poms.StreamOut;

public interface IStreamPomsRequestHandler
{
    IAsyncEnumerable<PomResponse> Handle(StreamPomsRequest request);
}

[ExcludeFromCodeCoverage(Justification =
    "The stored procedure call is not compatible with SQLite or InMemory databases.")]
public sealed class StreamPomsRequestHandler(SynapseContext dbContext)
    : IStreamPomsRequestHandler
{
    public async IAsyncEnumerable<PomResponse> Handle(StreamPomsRequest request)
    {
        var poms = dbContext
            .PayCalPoms
            .FromSqlInterpolated($"EXEC [dbo].[sp_GetPaycalPomData] @RelativeYear={request.RelativeYear}")
            .AsNoTracking()
            .WithTimeout(TimeSpan.FromMinutes(10)) // Necessary due to poor db performance
            .AsAsyncEnumerable();

        await foreach (var pom in poms)
            yield return new PomResponse
            {
                SubmissionPeriod = pom.SubmissionPeriod!,
                SubmissionPeriodDescription = pom.SubmissionPeriodDescription,
                OrganisationId = pom.OrganisationId!.Value,
                SubsidiaryId = pom.SubsidiaryId,
                PackagingType = pom.PackagingType,
                PackagingMaterial = pom.PackagingMaterial,
                PackagingMaterialSubType = pom.PackagingMaterialSubType,
                PackagingMaterialWeight = pom.PackagingMaterialWeight,
                PackagingClass = pom.PackagingClass,
                PackagingActivity = pom.PackagingActivity,
                RamRagRating = pom.RamRagRating,
                SubmitterId = pom.SubmitterId
            };
    }
}