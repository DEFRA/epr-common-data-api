using System.Diagnostics.CodeAnalysis;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace EPR.CommonDataService.Api.Features.Migration.RegistrationHistory;

public interface IStreamRegistrationHistoryRequestHandler
{
    IAsyncEnumerable<RegistrationHistoryResponse> Handle();
}

[ExcludeFromCodeCoverage(Justification =
    "The raw Synapse SQL batch is not compatible with SQLite or InMemory databases.")]
public sealed class StreamRegistrationHistoryRequestHandler(SynapseContext dbContext)
    : IStreamRegistrationHistoryRequestHandler
{
    public async IAsyncEnumerable<RegistrationHistoryResponse> Handle()
    {
        var rows = dbContext
            .RegistrationHistoryRows
            .FromSqlRaw(RegistrationHistorySql.Load())
            .AsNoTracking()
            .WithTimeout(TimeSpan.FromMinutes(30))
            .AsAsyncEnumerable();

        await foreach (var row in rows)
            yield return new RegistrationHistoryResponse
            {
                SubmissionId = row.SubmissionId,
                FileId = row.FileId,
                BlobName = row.BlobName,
                OrganisationId = row.OrganisationId,
                ComplianceSchemeId = row.ComplianceSchemeId,
                SubmissionPeriod = row.SubmissionPeriod,
                RegistrationJourney = row.RegistrationJourney,
                RegulatorNation = row.RegulatorNation,
                Roles = row.Roles,
                EventType = row.EventType,
                EventTypeOrder = row.EventTypeOrder,
                ReplayTs = row.ReplayTs,
                EventDate = row.EventDate,
                ApplicationReferenceNumber = row.ApplicationReferenceNumber,
                Decision = row.Decision,
            };
    }
}
