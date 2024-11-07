using Azure.Core;
using EPR.CommonDataService.Core.Extensions;
using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using System.Data;

namespace EPR.CommonDataService.Core.Services;

public interface ISubmissionsService
{
    Task<PaginatedResponse<PomSubmissionSummary>> GetSubmissionPomSummaries<T>(SubmissionsSummariesRequest<T> request);

    Task<PaginatedResponse<RegistrationSubmissionSummary>> GetSubmissionRegistrationSummaries<T>(SubmissionsSummariesRequest<T> request);

    Task<IList<ApprovedSubmissionEntity>> GetApprovedSubmissionsWithAggregatedPomData(DateTime approvedAfter, string periods);
}

public class SubmissionsService(SynapseContext accountsDbContext, IDatabaseTimeoutService databaseTimeoutService, ILogger<SubmissionsService> logger, IConfiguration config) : ISubmissionsService
{
    private readonly string? logPrefix = config["LogPrefix"];

    public async Task<PaginatedResponse<PomSubmissionSummary>> GetSubmissionPomSummaries<T>(SubmissionsSummariesRequest<T> request)
    {
        logger.LogInformation("{Logprefix}: SubmissionsService - GetSubmissionPomSummaries: Get Pom Submissions for given request {PomSubmissions}", logPrefix, JsonConvert.SerializeObject(request));

        var sql = "EXECUTE apps.sp_FilterAndPaginateSubmissionsSummaries @OrganisationName, @OrganisationReference, @RegulatorUserId, @StatusesCommaSeperated, @OrganisationType, @PageSize, @PageNumber, @DecisionsDelta, @SubmissionYearsCommaSeperated, @SubmissionPeriodsCommaSeperated, @ActualSubmissionPeriodsCommaSeperated";
        logger.LogInformation("{Logprefix}: SubmissionsService - GetSubmissionPomSummaries: executing query {Sql}", logPrefix, sql);

        var sqlParameters = request.ToProcParams();
        logger.LogInformation("{Logprefix}: SubmissionsService - GetSubmissionPomSummaries: query parameters {Parameters}", logPrefix, JsonConvert.SerializeObject(sqlParameters));

        var response = await accountsDbContext.RunSqlAsync<PomSubmissionSummaryRow>(sql, sqlParameters);
        var itemsCount = response.FirstOrDefault()?.TotalItems ?? 0;
        var paginatedResponse = response.ToPaginatedResponse<PomSubmissionSummaryRow, T, PomSubmissionSummary>(request, itemsCount);

        logger.LogInformation("{Logprefix}: SubmissionsService - GetSubmissionPomSummaries: Sql query response {Sql}", logPrefix, JsonConvert.SerializeObject(paginatedResponse));
        return paginatedResponse;
    }

    public async Task<PaginatedResponse<RegistrationSubmissionSummary>> GetSubmissionRegistrationSummaries<T>(SubmissionsSummariesRequest<T> request)
    {
        logger.LogInformation("{Logprefix}: SubmissionsService - GetSubmissionRegistrationSummaries: Get Registration Submissions for given request {RegistrationSubmissions}", logPrefix, JsonConvert.SerializeObject(request));

        var sql = "EXECUTE apps.sp_FilterAndPaginateRegistrationsSummaries @OrganisationName, @OrganisationReference, @RegulatorUserId, @StatusesCommaSeperated, @OrganisationType, @PageSize, @PageNumber, @DecisionsDelta, @SubmissionYearsCommaSeperated, @ActualSubmissionPeriodsCommaSeperated";
        logger.LogInformation("{Logprefix}: SubmissionsService - GetSubmissionRegistrationSummaries: executing query {Sql}", logPrefix, sql);

        var sqlParameters = request.ToProcParams();
        logger.LogInformation("{Logprefix}: SubmissionsService - GetSubmissionRegistrationSummaries: query parameters {Parameters}", logPrefix, JsonConvert.SerializeObject(sqlParameters));

        var response = await accountsDbContext.RunSqlAsync<RegistrationsSubmissionSummaryRow>(sql, sqlParameters);
        var itemsCount = response.FirstOrDefault()?.TotalItems ?? 0;
        var paginatedResponse = response.ToPaginatedResponse<RegistrationsSubmissionSummaryRow, T, RegistrationSubmissionSummary>(request, itemsCount);

        logger.LogInformation("{Logprefix}: SubmissionsService - GetSubmissionRegistrationSummaries: Sql query response {Sql}", logPrefix, JsonConvert.SerializeObject(paginatedResponse));
        return paginatedResponse;
    }

    public async Task<IList<ApprovedSubmissionEntity>> GetApprovedSubmissionsWithAggregatedPomData(DateTime approvedAfter, string periods)
    {
        logger.LogInformation("{Logprefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomData: Get approved submissions after {ApprovedAfter}, for periods {Periods}", logPrefix, approvedAfter.ToString(), periods);

        var sql = "EXECUTE rpd.sp_GetApprovedSubmissionsWithAggregatedPomDataV2 @ApprovedAfter, @Periods";
        logger.LogInformation("{Logprefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomData: executing query {Sql}", logPrefix, sql);

        try
        {
            databaseTimeoutService.SetCommandTimeout(accountsDbContext, 120);
            var paginatedResponse = await accountsDbContext.RunSqlAsync<ApprovedSubmissionEntity>(sql,
                new SqlParameter("@ApprovedAfter", SqlDbType.DateTime2) { Value = approvedAfter },
                new SqlParameter("@Periods", SqlDbType.VarChar) { Value = periods ?? (object)DBNull.Value });

            logger.LogInformation("{Logprefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomData: Sql query response {Sql}", logPrefix, JsonConvert.SerializeObject(paginatedResponse));
            return paginatedResponse;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomData: An error occurred while accessing the database. - {Ex}", logPrefix, ex.Message);
            throw new DataException("An error occurred while accessing the database.", ex);
        }
    }
}