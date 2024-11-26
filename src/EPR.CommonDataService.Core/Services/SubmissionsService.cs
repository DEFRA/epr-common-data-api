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
using System.Globalization;

// ReSharper disable CoVariantArrayConversion

namespace EPR.CommonDataService.Core.Services;

public interface ISubmissionsService
{
    Task<PaginatedResponse<PomSubmissionSummary>> GetSubmissionPomSummaries<T>(SubmissionsSummariesRequest<T> request);

    Task<PaginatedResponse<RegistrationSubmissionSummary>> GetSubmissionRegistrationSummaries<T>(SubmissionsSummariesRequest<T> request);

    Task<IList<ApprovedSubmissionEntity>> GetApprovedSubmissionsWithAggregatedPomData(DateTime approvedAfter, string periods);
}

public class SubmissionsService(SynapseContext accountsDbContext, IDatabaseTimeoutService databaseTimeoutService, ILogger<SubmissionsService> logger, IConfiguration config) : ISubmissionsService
{
    private readonly string? _logPrefix = string.IsNullOrEmpty(config["LogPrefix"]) ? "[EPR.CommonDataService]" : config["LogPrefix"];

    public async Task<PaginatedResponse<PomSubmissionSummary>> GetSubmissionPomSummaries<T>(SubmissionsSummariesRequest<T> request)
    {
        logger.LogInformation("{LogPrefix}: SubmissionsService - GetSubmissionPomSummaries: Get Pom Submissions for given request {PomSubmissions}", _logPrefix, JsonConvert.SerializeObject(request));

        var sql = "EXECUTE apps.sp_FilterAndPaginateSubmissionsSummaries @OrganisationName, @OrganisationReference, @RegulatorUserId, @StatusesCommaSeperated, @OrganisationType, @PageSize, @PageNumber, @DecisionsDelta, @SubmissionYearsCommaSeperated, @SubmissionPeriodsCommaSeperated, @ActualSubmissionPeriodsCommaSeperated";
        logger.LogInformation("{LogPrefix}: SubmissionsService - GetSubmissionPomSummaries: executing query {Sql}", _logPrefix, sql);

        var sqlParameters = request.ToProcParams();
        logger.LogInformation("{LogPrefix}: SubmissionsService - GetSubmissionPomSummaries: query parameters {Parameters}", _logPrefix, JsonConvert.SerializeObject(sqlParameters));

        var response = await accountsDbContext.RunSqlAsync<PomSubmissionSummaryRow>(sql, sqlParameters);
        var itemsCount = response.FirstOrDefault()?.TotalItems ?? 0;
        var paginatedResponse = response.ToPaginatedResponse<PomSubmissionSummaryRow, T, PomSubmissionSummary>(request, itemsCount);

        logger.LogInformation("{LogPrefix}: SubmissionsService - GetSubmissionPomSummaries: Sql query response {Sql}", _logPrefix, JsonConvert.SerializeObject(paginatedResponse));
        return paginatedResponse;
    }

    public async Task<PaginatedResponse<RegistrationSubmissionSummary>> GetSubmissionRegistrationSummaries<T>(SubmissionsSummariesRequest<T> request)
    {
        logger.LogInformation("{LogPrefix}: SubmissionsService - GetSubmissionRegistrationSummaries: Get Registration Submissions for given request {RegistrationSubmissions}", _logPrefix, JsonConvert.SerializeObject(request));

        var sql = "EXECUTE apps.sp_FilterAndPaginateRegistrationsSummaries @OrganisationName, @OrganisationReference, @RegulatorUserId, @StatusesCommaSeperated, @OrganisationType, @PageSize, @PageNumber, @DecisionsDelta, @SubmissionYearsCommaSeperated, @ActualSubmissionPeriodsCommaSeperated";
        logger.LogInformation("{LogPrefix}: SubmissionsService - GetSubmissionRegistrationSummaries: executing query {Sql}", _logPrefix, sql);

        var sqlParameters = request.ToProcParams();
        logger.LogInformation("{LogPrefix}: SubmissionsService - GetSubmissionRegistrationSummaries: query parameters {Parameters}", _logPrefix, JsonConvert.SerializeObject(sqlParameters));

        var response = await accountsDbContext.RunSqlAsync<RegistrationsSubmissionSummaryRow>(sql, sqlParameters);
        var itemsCount = response.FirstOrDefault()?.TotalItems ?? 0;
        var paginatedResponse = response.ToPaginatedResponse<RegistrationsSubmissionSummaryRow, T, RegistrationSubmissionSummary>(request, itemsCount);

        logger.LogInformation("{LogPrefix}: SubmissionsService - GetSubmissionRegistrationSummaries: Sql query response {Sql}", _logPrefix, JsonConvert.SerializeObject(paginatedResponse));
        return paginatedResponse;
    }

    public async Task<IList<ApprovedSubmissionEntity>> GetApprovedSubmissionsWithAggregatedPomData(DateTime approvedAfter, string periods)
    {
        logger.LogInformation("{LogPrefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomData: Get approved submissions after {ApprovedAfter}, for periods {Periods}", _logPrefix, approvedAfter.ToString(CultureInfo.InvariantCulture), periods);

        var sql = "EXECUTE rpd.sp_GetApprovedSubmissionsWithAggregatedPomDataV2 @ApprovedAfter, @Periods";
        logger.LogInformation("{LogPrefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomData: executing query {Sql}", _logPrefix, sql);

        try
        {
            databaseTimeoutService.SetCommandTimeout(accountsDbContext, 120);
            var paginatedResponse = await accountsDbContext.RunSqlAsync<ApprovedSubmissionEntity>(sql,
                new SqlParameter("@ApprovedAfter", SqlDbType.DateTime2) { Value = approvedAfter },
                new SqlParameter("@Periods", SqlDbType.VarChar) { Value = periods ?? (object)DBNull.Value });

            logger.LogInformation("{LogPrefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomData: Sql query response {Sql}", _logPrefix, JsonConvert.SerializeObject(paginatedResponse));
            return paginatedResponse;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "{LogPrefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomData: An error occurred while accessing the database. - {Ex}", _logPrefix, ex.Message);
            throw new DataException("An error occurred while accessing the database.", ex);
        }
    }
}