using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Core.UnitTests.TestHelpers;

[ExcludeFromCodeCoverage]
public static class SubmissionEventTestHelper
{
    public static void SetupDatabaseForSubmissionEvents(SynapseContext setupContext)
    {
        setupContext.Database.EnsureDeleted();
        setupContext.Database.EnsureCreated();

        var submissionEvents = new List<SubmissionEvent>
        {
            new() {
                SubmissionEventId = Guid.NewGuid().ToString(),
                LastSyncTime = DateTime.Today
            },
            new() {
                SubmissionEventId = Guid.NewGuid().ToString(),
                LastSyncTime = DateTime.Today.AddDays(-1)
            }
        };

        setupContext.SubmissionEvents.AddRange(submissionEvents);
        setupContext.SaveChanges();
    }
}