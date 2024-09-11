using EPR.CommonDataService.Core.Extensions;
using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;
using System.Data;

namespace EPR.CommonDataService.Core.Services;

public class SubmissionsService : ISubmissionsService
{
    private readonly SynapseContext _synapseContext;
    private readonly IDatabaseTimeoutService _databaseTimeoutService;

    public SubmissionsService(SynapseContext accountsDbContext, IDatabaseTimeoutService databaseTimeoutService)
    {
        _synapseContext = accountsDbContext;
        _databaseTimeoutService = databaseTimeoutService;
    }

    public async Task<PaginatedResponse<PomSubmissionSummary>> GetSubmissionPomSummaries<T>(SubmissionsSummariesRequest<T> request)
    {
        var sql = "EXECUTE apps.sp_FilterAndPaginateSubmissionsSummaries @OrganisationName, @OrganisationReference, @RegulatorUserId, @StatusesCommaSeperated, @OrganisationType, @PageSize, @PageNumber, @DecisionsDelta, @SubmissionYearsCommaSeperated, @SubmissionPeriodsCommaSeperated, @ActualSubmissionPeriodsCommaSeperated";

        var sqlParameters = request.ToProcParams();

        var response = await _synapseContext.RunSqlAsync<PomSubmissionSummaryRow>(sql, sqlParameters);
        var itemsCount = response.FirstOrDefault()?.TotalItems ?? 0;

        return response.ToPaginatedResponse<PomSubmissionSummaryRow, T, PomSubmissionSummary>(request, itemsCount);
    }

    public async Task<PaginatedResponse<RegistrationSubmissionSummary>> GetSubmissionRegistrationSummaries<T>(SubmissionsSummariesRequest<T> request)
    {
        var sql = "EXECUTE apps.sp_FilterAndPaginateRegistrationsSummaries @OrganisationName, @OrganisationReference, @RegulatorUserId, @StatusesCommaSeperated, @OrganisationType, @PageSize, @PageNumber, @DecisionsDelta, @SubmissionYearsCommaSeperated, @ActualSubmissionPeriodsCommaSeperated";

        var sqlParameters = request.ToProcParams();

        var response = await _synapseContext.RunSqlAsync<RegistrationsSubmissionSummaryRow>(sql, sqlParameters);
        var itemsCount = response.FirstOrDefault()?.TotalItems ?? 0;

        return response.ToPaginatedResponse<RegistrationsSubmissionSummaryRow, T, RegistrationSubmissionSummary>(request, itemsCount);
    }

    public async Task<IList<ApprovedSubmissionEntity>> GetApprovedSubmissionsWithAggregatedPomData(DateTime approvedAfter)
    {
        var sql = "EXECUTE rpd.sp_GetApprovedSubmissionsWithAggregatedPomData3 @ApprovedAfter";

        try
        {
            _databaseTimeoutService.SetCommandTimeout(_synapseContext, 120);

            return await _synapseContext.RunSqlAsync<ApprovedSubmissionEntity>(sql, new SqlParameter("@ApprovedAfter", SqlDbType.DateTime2) { Value = approvedAfter });
        }
        catch (SqlException ex) when (ex.Number == -2)
        {
            throw new TimeoutException("The request timed out while accessing the database.", ex);
        }
    }
}