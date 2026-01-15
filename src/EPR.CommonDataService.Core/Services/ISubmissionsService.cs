using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Data.Entities;

namespace EPR.CommonDataService.Core.Services;

public interface ISubmissionsService
{
    Task<PaginatedResponse<PomSubmissionSummary>> GetSubmissionPomSummaries<T>(SubmissionsSummariesRequest<T> request);

    Task<PaginatedResponse<RegistrationSubmissionSummary>> GetSubmissionRegistrationSummaries<T>(SubmissionsSummariesRequest<T> request);

    Task<IList<ApprovedSubmissionEntity>> GetApprovedSubmissionsWithAggregatedPomData(DateTime approvedAfter, string periods, string includePackagingTypes, string includePackagingMaterials, string includeOrganisationSize);

    Task<IList<ApprovedSubmissionEntity>> GetApprovedSubmissionsWithAggregatedPomDataMyc(int periodYear, string includePackagingTypes, string includePackagingMaterials);

    Task<PaginatedResponse<OrganisationRegistrationSummaryDto>?> GetOrganisationRegistrationSubmissionSummaries(int NationId, OrganisationRegistrationFilterRequest filter);

    Task<OrganisationRegistrationDetailsDto?> GetOrganisationRegistrationSubmissionDetails(OrganisationRegistrationDetailRequest request);

    Task<PomResubmissionPaycalParametersDto?> GetResubmissionPaycalParameters(string sanitisedSubmissionId, string? sanitisedComplianceSchemeId);

    Task<bool?> IsCosmosDataAvailable(string? sanitisedSubmissionId, string? sanitisedFileId);

    Task<string> GetActualSubmissionPeriod(string sanitisedSubmissionId, string submissionPeriod);

    Task<bool> IsPOMResubmissionDataSynchronised(string sanitisedFileId);
}