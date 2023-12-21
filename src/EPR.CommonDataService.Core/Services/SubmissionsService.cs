using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using EPR.CommonDataService.Core.Extensions;
using EPR.CommonDataService.Core.Models.Response;

namespace EPR.CommonDataService.Core.Services;

public class SubmissionsService : ISubmissionsService
{
    private readonly SynapseContext _synapseContext;

    public SubmissionsService(SynapseContext accountsDbContext)
    {
        _synapseContext = accountsDbContext;
    }
    
    public async Task<PaginatedResponse<PomSubmissionSummary>> GetSubmissionPomSummaries(PomSubmissionsSummariesRequest request)
    {
        string sql = "EXECUTE apps.sp_FilterAndPaginateSubmissionsSummaries @OrganisationName, @OrganisationReference, @RegulatorUserId, @StatusesCommaSeperated, @OrganisationType, @PageSize, @PageNumber, @DecisionsDelta";

        var sqlParameters = request.ToProcParams();
        
        var response = await _synapseContext.RunSqlAsync<PomSubmissionSummaryRow>(sql, sqlParameters);

        return response.ToPaginatedResponse(request);
    }
}