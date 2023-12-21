using EPR.CommonDataService.Core.Models;

namespace EPR.CommonDataService.Core.Services;

public interface ISubmissionEventService
{
    Task<SubmissionEventsLastSync> GetLastSyncTimeAsync();
}