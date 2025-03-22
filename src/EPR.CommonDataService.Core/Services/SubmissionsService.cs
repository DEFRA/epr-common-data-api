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

    public async Task<IList<ApprovedSubmissionEntity>> GetApprovedSubmissionsWithAggregatedPomData(DateTime approvedAfter, string periods, string includePackagingTypes, string includePackagingMaterials, string includeOrganisationSize)
    {
        logger.LogInformation("{LogPrefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomData: Get approved submissions after {ApprovedAfter}, for periods {Periods}, " +
            "including packaging types {IncludePackagingTypes}, including packaging materials {IncludePackagingMaterials} and including organisation size {IncludeOrganisationSize}",
            _logPrefix, approvedAfter.ToString(CultureInfo.InvariantCulture), periods, includePackagingTypes, includePackagingMaterials, includeOrganisationSize);

        var sql = "EXECUTE rpd.sp_GetApprovedSubmissions @ApprovedAfter, @Periods, @IncludePackagingTypes, @IncludePackagingMaterials, @IncludeOrganisationSize";
        logger.LogInformation("{LogPrefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomData: executing query {Sql}", _logPrefix, sql);

        try
        {
            databaseTimeoutService.SetCommandTimeout(accountsDbContext, 120);
            var paginatedResponse = await accountsDbContext.RunSqlAsync<ApprovedSubmissionEntity>(sql,
                new SqlParameter("@ApprovedAfter", SqlDbType.DateTime2) { Value = approvedAfter },
                new SqlParameter("@Periods", SqlDbType.VarChar) { Value = periods ?? (object)DBNull.Value },
                new SqlParameter("@IncludePackagingTypes", SqlDbType.VarChar) { Value = includePackagingTypes ?? (object)DBNull.Value },
                new SqlParameter("@IncludePackagingMaterials", SqlDbType.VarChar) { Value = includePackagingMaterials ?? (object)DBNull.Value },
                new SqlParameter("@IncludeOrganisationSize", SqlDbType.VarChar) { Value = includeOrganisationSize ?? (object)DBNull.Value });

            logger.LogInformation("{LogPrefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomData: Sql query response {Sql}", _logPrefix, JsonConvert.SerializeObject(paginatedResponse));
            return paginatedResponse;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "{LogPrefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomData: An error occurred while accessing the database. - {Ex}", _logPrefix, ex.Message);
            throw new DataException("An error occurred while accessing the database.", ex);
        }
    }

    public async Task<PaginatedResponse<OrganisationRegistrationSummaryDto>?> GetOrganisationRegistrationSubmissionSummaries(int NationId, OrganisationRegistrationFilterRequest filter)
    {
        logger.LogInformation("{Logprefix}: SubmissionsService - GetOrganisationRegistrationSubmissionSummaries: Get OrganisationRegistrationSubmissions for given request", _logPrefix);
        var sql = "EXECUTE dbo.sp_FilterAndPaginateOrganisationRegistrationSummaries @OrganisationNameCommaSeparated, @OrganisationReferenceCommaSeparated, @SubmissionYearsCommaSeparated, @StatusesCommaSeparated, @OrganisationTypeCommaSeparated, @NationId, @AppRefNumbersCommaSeparated, @PageSize, @PageNumber";

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
            logger.LogInformation("{Logprefix}: SubmissionsService - GetOrganisationRegistrationSubmissionSummaries: Query Response {Dataset}", _logPrefix, JsonConvert.SerializeObject(dataset));

            return dataset.ToCalculatedPaginatedResponse<OrganisationRegistrationSummaryDataRow, OrganisationRegistrationSummaryDto>(filter, itemsCount);
        }
        catch (SqlException ex) when (ex.Number == -2)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsService - GetOrganisationRegistrationSubmissionSummaries: A Timeout error occurred while accessing the database. - {Ex}", _logPrefix, ex.Message);
            throw new TimeoutException("The request timed out while accessing the database.", ex);
        }
        catch (SqlException ex)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsService - GetOrganisationRegistrationSubmissionSummaries: Get OrganisationRegistrationSubmissions: An error occurred while accessing the database. - {Ex}", _logPrefix, ex.Message);
            throw new DataException("An exception occurred when executing query.", ex);
        }
    }

    public async Task<OrganisationRegistrationDetailsDto?> GetOrganisationRegistrationSubmissionDetails(OrganisationRegistrationDetailRequest request)
    {
        logger.LogInformation("{Logprefix}: SubmissionsService - GetOrganisationRegistrationSubmissionDetails: Get OrganisationRegistrationSubmissionDetails for given request {Request}", _logPrefix, JsonConvert.SerializeObject(request));
        var sql = "dbo.sp_FetchOrganisationRegistrationSubmissionDetails";
        var sqlParameters = request.ToProcParams();

        try
        {
            databaseTimeoutService.SetCommandTimeout(accountsDbContext, 80);
            var dbSet = await accountsDbContext.RunSpCommandAsync<OrganisationRegistrationDetailsDto>(sql, logger, _logPrefix, sqlParameters);
            logger.LogInformation("{Logprefix}: SubmissionsService - GetOrganisationRegistrationSubmissionDetails: Get OrganisationRegistrationSubmissionDetails Query Response {Dataset}", _logPrefix, JsonConvert.SerializeObject(dbSet));

            return dbSet.FirstOrDefault();
        }
        catch (SqlException ex) when (ex.Number == -2)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsService - GetOrganisationRegistrationSubmissionDetails: A Timeout error occurred while accessing the database. - {Ex}", _logPrefix, ex.Message);
            throw new TimeoutException("The request timed out while accessing the database.", ex);
        }
        catch (SqlException ex)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsService - GetOrganisationRegistrationSubmissionDetails: Get GetOrganisationRegistrationSubmissionDetails: An error occurred while accessing the database. - {Ex}", _logPrefix, ex.Message);
            throw new DataException("An exception occurred when executing query.", ex);
        }
    }
}