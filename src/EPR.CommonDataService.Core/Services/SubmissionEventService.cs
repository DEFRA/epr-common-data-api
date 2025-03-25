using EPR.CommonDataService.Core.Models;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace EPR.CommonDataService.Core.Services;

public interface ISubmissionEventService
{
    Task<SubmissionEventsLastSync> GetLastSyncTimeAsync();
}

public class SubmissionEventService(
    SynapseContext accountsDbContext, ILogger<SubmissionsService> logger) 
    : ISubmissionEventService
{
    public async Task<SubmissionEventsLastSync> GetLastSyncTimeAsyncOld()
    {
        var lastSyncTime =  await accountsDbContext.SubmissionEvents.MaxAsync(se => se.LastSyncTime);
        return new SubmissionEventsLastSync
        {
            LastSyncTime = lastSyncTime
        };
    }

    public async Task<SubmissionEventsLastSync> GetLastSyncTimeAsync()
    {
        var sql = "dbo.GetLastSyncTime";

        var response = await accountsDbContext.RunSpCommandAsync<SubmissionEventsLastSync>(sql, logger, "GetLastSyncTime", []);
        if ( response.Count == 0 )
        {
            Exception exception = new("No data found from GetLastSyncTime");
            throw exception;
        }
        return response[0];
    }
}
