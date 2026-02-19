using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace EPR.CommonDataService.Api.Features.PayCal.Organisations.StreamOut;

public interface IStreamOrganisationsRequestHandler
{
    IAsyncEnumerable<OrganisationResponse> Handle(StreamOrganisationsRequest request);
}

public sealed class StreamOrganisationsRequestHandler(SynapseContext dbContext)
    : IStreamOrganisationsRequestHandler
{
    public async IAsyncEnumerable<OrganisationResponse> Handle(StreamOrganisationsRequest request)
    {
        var organisations = dbContext
            .PayCalOrganisations
            .AsNoTracking()
            .Where(org => org.SubmissionPeriodYear == request.RelativeYear)
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
                SubmitterId = org.SubmitterId
            };
    }
}