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

public class SubmissionsService(SynapseContext accountsDbContext, IDatabaseTimeoutService databaseTimeoutService, ILogger<SubmissionsService> logger, IConfiguration config) : ISubmissionsService
{
    private readonly string? logPrefix = string.IsNullOrEmpty(config["LogPrefix"]) ? "[EPR.CommonDataService]" : config["LogPrefix"];

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

    public async Task<PaginatedResponse<OrganisationRegistrationSummaryDto>> GetOrganisationRegistrationSubmissionSummaries(int NationId, OrganisationRegistrationFilterRequest filter)
    {
        logger.LogInformation("{Logprefix}: SubmissionsService - GetOrganisationRegistrationSubmissionSummaries: Get OrganisationRegistrationSubmissions for given request", logPrefix);
        var sql = "EXECUTE rpd.sp_FilterAndPaginateOrganisationRegistrationSummaries @OrganisationNameCommaSeparated, @OrganisationReferenceCommaSeparated, @SubmissionYearsCommaSeparated, @StatusesCommaSeparated, @OrganisationTypeCommaSeparated, @NationId, @AppRefNumbersCommaSeparated, @PageSize, @PageNumber";

        SqlParameter[] sqlParameters = filter.ToProcParams();

        sqlParameters =
        [
            .. sqlParameters,
            new SqlParameter("@NationId", SqlDbType.Int) { Value = NationId },
        ];

        try
        {
            databaseTimeoutService.SetCommandTimeout(accountsDbContext, 120);
            var dataset = await accountsDbContext.RunSqlAsync<OrganisationRegistrationSummaryDataRow>(sql, sqlParameters);
            var itemsCount = dataset.FirstOrDefault()?.TotalItems ?? 0;
            logger.LogInformation("{Logprefix}: SubmissionsService - GetOrganisationRegistrationSubmissionSummaries: Query Response {Dataset}", logPrefix, JsonConvert.SerializeObject(dataset));

            return dataset.ToCalculatedPaginatedResponse<OrganisationRegistrationSummaryDataRow, OrganisationRegistrationSummaryDto>(filter, itemsCount);
        }
        catch (SqlException ex) when (ex.Number == -2)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsService - GetOrganisationRegistrationSubmissionSummaries: A Timeout error occurred while accessing the database. - {Ex}", logPrefix, ex.Message);
            throw new TimeoutException("The request timed out while accessing the database.", ex);
        }
        catch (SqlException ex)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsService - GetOrganisationRegistrationSubmissionSummaries: Get OrganisationRegistrationSubmissions: An error occurred while accessing the database. - {Ex}", logPrefix, ex.Message);
            throw new DataException("An exception occurred when executing query.", ex);
        }
    }

    public async Task<OrganisationRegistrationDetailsDto?> GetOrganisationRegistrationSubmissionDetails(OrganisationRegistrationDetailRequest request)
    {
        logger.LogInformation("{Logprefix}: SubmissionsService - GetOrganisationRegistrationSubmissionDetails: Get OrganisationRegistrationSubmissionDetails for given request {Request}", logPrefix, JsonConvert.SerializeObject(request));
        var sql = "EXECUTE rpd.sp_fetchOrganisationRegistrationSubmissionDetails @SubmissionId";
        var sqlParameters = request.ToProcParams();

        try
        {
            databaseTimeoutService.SetCommandTimeout(accountsDbContext, 80);
            var dataset = await accountsDbContext.RunSqlAsync<OrganisationRegistrationDetailsDto>(sql, sqlParameters);
            logger.LogInformation("{Logprefix}: SubmissionsService - GetOrganisationRegistrationSubmissionDetails: Get OrganisationRegistrationSubmissionDetails Query Response {Dataset}", logPrefix, JsonConvert.SerializeObject(dataset));

            return dataset.FirstOrDefault();
        }
        catch (SqlException ex) when (ex.Number == -2)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsService - GetOrganisationRegistrationSubmissionDetails: A Timeout error occurred while accessing the database. - {Ex}", logPrefix, ex.Message);
            throw new TimeoutException("The request timed out while accessing the database.", ex);
        }
        catch (SqlException ex)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsService - GetOrganisationRegistrationSubmissionDetails: Get GetOrganisationRegistrationSubmissionDetails: An error occurred while accessing the database. - {Ex}", logPrefix, ex.Message);
            throw new DataException("An exception occurred when executing query.", ex);
        }
    }
}