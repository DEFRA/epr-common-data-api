using EPR.CommonDataService.Core.Extensions;
using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;

namespace EPR.CommonDataService.Core.Services;

public class SubmissionsService : ISubmissionsService
{
    private readonly SynapseContext _synapseContext;

    public SubmissionsService(SynapseContext accountsDbContext)
    {
        _synapseContext = accountsDbContext;
    }
    
    public async Task<PaginatedResponse<PomSubmissionSummary>> GetSubmissionPomSummaries<T>(SubmissionsSummariesRequest<T> request)
    {
        string sql = "EXECUTE apps.sp_FilterAndPaginateSubmissionsSummaries_new @OrganisationName, @OrganisationReference, @RegulatorUserId, @StatusesCommaSeperated, @OrganisationType, @PageSize, @PageNumber, @DecisionsDelta, @SubmissionYearsCommaSeperated, @SubmissionPeriodsCommaSeperated, @ActualSubmissionPeriodsCommaSeperated";

        var sqlParameters = request.ToProcParams();
        
        var response = await _synapseContext.RunSqlAsync<PomSubmissionSummaryRow>(sql, sqlParameters);
        var itemsCount = response.FirstOrDefault()?.TotalItems ?? 0;

        return response.ToPaginatedResponse<PomSubmissionSummaryRow,T,PomSubmissionSummary>(request,itemsCount);
    }
    
    public async Task<PaginatedResponse<RegistrationSubmissionSummary>> GetSubmissionRegistrationSummaries<T>(SubmissionsSummariesRequest<T> request)
    {
        string sql = "EXECUTE apps.sp_FilterAndPaginateRegistrationsSummaries_new @OrganisationName, @OrganisationReference, @RegulatorUserId, @StatusesCommaSeperated, @OrganisationType, @PageSize, @PageNumber, @DecisionsDelta, @SubmissionYearsCommaSeperated, @SubmissionPeriodsCommaSeperated";

        var sqlParameters = request.ToProcParams();
        
        var response = await _synapseContext.RunSqlAsync<RegistrationsSubmissionSummaryRow>(sql, sqlParameters);
        var itemsCount = response.FirstOrDefault()?.TotalItems ?? 0;

        return response.ToPaginatedResponse<RegistrationsSubmissionSummaryRow,T,RegistrationSubmissionSummary>(request,itemsCount);
    }
}