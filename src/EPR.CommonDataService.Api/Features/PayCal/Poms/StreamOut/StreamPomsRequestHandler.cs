using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace EPR.CommonDataService.Api.Features.PayCal.Poms.StreamOut;

public interface IStreamPomsRequestHandler
{
    IAsyncEnumerable<PomResponse> Handle(StreamPomsRequest request);
}

public sealed class StreamPomsRequestHandler(SynapseContext dbContext)
    : IStreamPomsRequestHandler
{
    public async IAsyncEnumerable<PomResponse> Handle(StreamPomsRequest request)
    {
        // SQL filter to match all POM SubmissionPeriods for the requested RelativeYear.
        // For POMs this should be the year prior to RelativeYear.
        var filter = $"{request.RelativeYear - 1}%";

        var poms = dbContext
            .PayCalPoms
            .WithTimeout(TimeSpan.FromMinutes(10)) // Necessary due to the poor performance of the underlying view
            .AsNoTracking()
            // ReSharper disable once EntityFramework.ClientSideDbFunctionCall - Incorrect analysis result (due to WithTimeout extension method)
            // Synapse requires use of EF.Functions
            .Where(x => EF.Functions.Like(x.SubmissionPeriod, filter))
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
                PackagingMaterialWeight = pom.PackagingMaterialWeight,
                PackagingClass = pom.PackagingClass,
                PackagingActivity = pom.PackagingActivity,
                SubmitterId = pom.SubmitterId
            };
    }
}