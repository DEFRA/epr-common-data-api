using EPR.CommonDataService.Core.Extensions;
using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Extensions.Configuration;

namespace EPR.CommonDataService.Core.Services;

public class SubmissionsService : ISubmissionsService
{
    private readonly SynapseContext _synapseContext;
    private readonly IConfiguration _configuration;

    public SubmissionsService(SynapseContext accountsDbContext, IConfiguration configuration)
    {
        _synapseContext = accountsDbContext;
        _configuration = configuration;
    }
    
    public async Task<PaginatedResponse<PomSubmissionSummary>> GetSubmissionPomSummaries<T>(SubmissionsSummariesRequest<T> request)
    {
        string sql = "EXECUTE apps.sp_FilterAndPaginateSubmissionsSummaries @OrganisationName, @OrganisationReference, @RegulatorUserId, @StatusesCommaSeperated, @OrganisationType, @PageSize, @PageNumber, @DecisionsDelta";

        request.UserId = _configuration.GetConnectionString("RegulatorUserId") != null 
            ? new Guid(_configuration.GetConnectionString("RegulatorUserId")) 
            : request.UserId;

        var sqlParameters = request.ToProcParams();
        
        var response = await _synapseContext.RunSqlAsync<PomSubmissionSummaryRow>(sql, sqlParameters);
        var itemsCount = response.FirstOrDefault()?.TotalItems ?? 0;

        return response.ToPaginatedResponse<PomSubmissionSummaryRow,T,PomSubmissionSummary>(request,itemsCount);
    }
    
    public async Task<PaginatedResponse<RegistrationSubmissionSummary>> GetSubmissionRegistrationSummaries<T>(SubmissionsSummariesRequest<T> request)
    {
        string sql = "EXECUTE apps.sp_FilterAndPaginateRegistrationsSummaries @OrganisationName, @OrganisationReference, @RegulatorUserId, @StatusesCommaSeperated, @OrganisationType, @PageSize, @PageNumber, @DecisionsDelta";

        request.UserId = _configuration.GetConnectionString("RegulatorUserId") != null
            ? new Guid(_configuration.GetConnectionString("RegulatorUserId"))
            : request.UserId;

        var sqlParameters = request.ToProcParams();
        
        var response = await _synapseContext.RunSqlAsync<RegistrationsSubmissionSummaryRow>(sql, sqlParameters);
        var itemsCount = response.FirstOrDefault()?.TotalItems ?? 0;

        return response.ToPaginatedResponse<RegistrationsSubmissionSummaryRow,T,RegistrationSubmissionSummary>(request,itemsCount);
    }
}