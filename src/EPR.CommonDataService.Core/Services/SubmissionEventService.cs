using EPR.CommonDataService.Core.Models;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace EPR.CommonDataService.Core.Services;

public interface ISubmissionEventService
{
    Task<SubmissionEventsLastSync> GetLastSyncTimeAsync();
}

public class SubmissionEventService : ISubmissionEventService
{
    private readonly SynapseContext _synapseContext;

    public SubmissionEventService(SynapseContext accountsDbContext)
    {
        _synapseContext = accountsDbContext;
    }
    
    public async Task<SubmissionEventsLastSync> GetLastSyncTimeAsync()
    {
        var lastSynctime =  await _synapseContext.SubmissionEvents.MaxAsync(se => se.LastSyncTime);
        return new SubmissionEventsLastSync
        {
            LastSyncTime = lastSynctime
        };
    }
}