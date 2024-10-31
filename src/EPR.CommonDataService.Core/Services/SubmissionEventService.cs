using EPR.CommonDataService.Core.Models;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace EPR.CommonDataService.Core.Services;

public interface ISubmissionEventService
{
    Task<SubmissionEventsLastSync> GetLastSyncTimeAsync();
}

public class SubmissionEventService(
    SynapseContext accountsDbContext) 
    : ISubmissionEventService
{
    public async Task<SubmissionEventsLastSync> GetLastSyncTimeAsync()
    {
        var lastSyncTime =  await accountsDbContext.SubmissionEvents.MaxAsync(se => se.LastSyncTime);
        return new SubmissionEventsLastSync
        {
            LastSyncTime = lastSyncTime
        };
    }
}