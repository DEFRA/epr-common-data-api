using System.Diagnostics.CodeAnalysis;
using System.Runtime.CompilerServices;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace EPR.CommonDataService.Api.Features.PayCal.v2.Poms.StreamOut;

public interface IStreamPomsRequestHandler
{
    IAsyncEnumerable<PomResponse> Handle(StreamPomsRequest request, CancellationToken cancellationToken);
}

[ExcludeFromCodeCoverage(Justification =
    "The stored procedure call is not compatible with SQLite or InMemory databases.")]
public sealed class StreamPomsRequestHandler(SynapseContext dbContext)
    : IStreamPomsRequestHandler
{
    public async IAsyncEnumerable<PomResponse> Handle(
        StreamPomsRequest request,
        [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        var poms = dbContext
            .PayCalPomsV2
            .FromSqlInterpolated($"EXEC [dbo].[sp_GetPaycalPomData_v2] @RelativeYear={request.RelativeYear}")
            .AsNoTracking()
            .WithTimeout(TimeSpan.FromMinutes(10)) // Necessary due to poor db performance
            .AsAsyncEnumerable()
            .WithCancellation(cancellationToken);

        await foreach (var pom in poms)
        {
            yield return new PomResponse
            {
                Filename = pom.Filename,
                SubmissionPeriod = pom.SubmissionPeriod!,
                SubmissionPeriodDescription = pom.SubmissionPeriodDescription,
                OrganisationId = pom.OrganisationId!.Value,
                SubsidiaryId = pom.SubsidiaryId,
                PackagingType = pom.PackagingType,
                PackagingMaterial = pom.PackagingMaterial,
                PackagingMaterialSubtype = pom.PackagingMaterialSubtype,
                PackagingMaterialWeight = pom.PackagingMaterialWeight,
                PackagingClass = pom.PackagingClass,
                PackagingActivity = pom.PackagingActivity,
                RamRagRating = pom.RamRagRating,
                SubmitterId = pom.SubmitterId,
                IsResubmission = pom.IsResubmission,
                CreatedAt = pom.CreatedAt is { } value ? new DateTimeOffset(value, TimeSpan.Zero) : null
            };
        }
    }
}
