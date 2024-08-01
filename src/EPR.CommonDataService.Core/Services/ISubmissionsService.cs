using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Data.Entities;

namespace EPR.CommonDataService.Core.Services;

public interface ISubmissionsService
{
    Task<PaginatedResponse<PomSubmissionSummary>> GetSubmissionPomSummaries<T>(SubmissionsSummariesRequest<T> request);

    Task<PaginatedResponse<RegistrationSubmissionSummary>> GetSubmissionRegistrationSummaries<T>(SubmissionsSummariesRequest<T> request);

    Task<IList<ApprovedSubmissionEntity>> GetApprovedSubmissions(DateTime approvedAfter);
}