using EPR.CommonDataService.Core.Extensions;
using EPR.CommonDataService.Core.Models;
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
        var sql = "EXECUTE [apps].[sp_FilterAndPaginateSubmissionsSummaries_resub] @OrganisationName, @OrganisationReference, @RegulatorUserId, @StatusesCommaSeperated, @OrganisationType, @PageSize, @PageNumber, @DecisionsDelta, @SubmissionYearsCommaSeperated, @SubmissionPeriodsCommaSeperated, @ActualSubmissionPeriodsCommaSeperated";

        var sqlParameters = request.ToProcParams();
        logger.LogInformation("{LogPrefix}: SubmissionsService - GetSubmissionPomSummaries: query {Query} parameters {Parameters}", _logPrefix, sql, JsonConvert.SerializeObject(sqlParameters));

        var response = await accountsDbContext.RunSqlAsync<PomSubmissionSummaryRow>(sql, sqlParameters);
        var itemsCount = response.FirstOrDefault()?.TotalItems ?? 0;
        var paginatedResponse = response.ToPaginatedResponse<PomSubmissionSummaryRow, T, PomSubmissionSummary>(request, itemsCount);

        return paginatedResponse;
    }

    public async Task<PaginatedResponse<RegistrationSubmissionSummary>> GetSubmissionRegistrationSummaries<T>(SubmissionsSummariesRequest<T> request)
    {
        var sql = "EXECUTE apps.sp_FilterAndPaginateRegistrationsSummaries @OrganisationName, @OrganisationReference, @RegulatorUserId, @StatusesCommaSeperated, @OrganisationType, @PageSize, @PageNumber, @DecisionsDelta, @SubmissionYearsCommaSeperated, @ActualSubmissionPeriodsCommaSeperated";
        var sqlParameters = request.ToProcParams();
        logger.LogInformation("{LogPrefix}: SubmissionsService - GetSubmissionRegistrationSummaries: query {Query} parameters {Parameters}", _logPrefix, sql, JsonConvert.SerializeObject(sqlParameters));

        var response = await accountsDbContext.RunSqlAsync<RegistrationsSubmissionSummaryRow>(sql, sqlParameters);
        var itemsCount = response.FirstOrDefault()?.TotalItems ?? 0;
        var paginatedResponse = response.ToPaginatedResponse<RegistrationsSubmissionSummaryRow, T, RegistrationSubmissionSummary>(request, itemsCount);

        return paginatedResponse;
    }

    public async Task<IList<ApprovedSubmissionEntity>> GetApprovedSubmissionsWithAggregatedPomData(DateTime approvedAfter, string periods, string includePackagingTypes, string includePackagingMaterials, string includeOrganisationSize)
    {
        logger.LogInformation("{LogPrefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomData: Get approved submissions after {ApprovedAfter}, for periods {Periods}, " +
            "including packaging types {IncludePackagingTypes}, including packaging materials {IncludePackagingMaterials} and including organisation size {IncludeOrganisationSize}",
            _logPrefix, approvedAfter.ToString(CultureInfo.InvariantCulture), periods, includePackagingTypes, includePackagingMaterials, includeOrganisationSize);

        var sql = "EXECUTE dbo.sp_GetApprovedSubmissions @ApprovedAfter, @Periods, @IncludePackagingTypes, @IncludePackagingMaterials, @IncludeOrganisationSize";
        logger.LogInformation("{LogPrefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomData: executing query {Sql}", _logPrefix, sql);

        try
        {
            databaseTimeoutService.SetCommandTimeout(accountsDbContext, 320);
            var paginatedResponse = await accountsDbContext.RunSqlAsync<ApprovedSubmissionEntity>(sql,
                new SqlParameter("@ApprovedAfter", SqlDbType.DateTime2) { Value = approvedAfter },
                new SqlParameter("@Periods", SqlDbType.VarChar) { Value = periods ?? (object)DBNull.Value },
                new SqlParameter("@IncludePackagingTypes", SqlDbType.VarChar) { Value = includePackagingTypes ?? (object)DBNull.Value },
                new SqlParameter("@IncludePackagingMaterials", SqlDbType.VarChar) { Value = includePackagingMaterials ?? (object)DBNull.Value },
                new SqlParameter("@IncludeOrganisationSize", SqlDbType.VarChar) { Value = includeOrganisationSize ?? (object)DBNull.Value });

            logger.LogInformation("{LogPrefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomData: Response received from stored procedure", _logPrefix);
            return paginatedResponse;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "{LogPrefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomData: An error occurred while accessing the database. - {Ex}", _logPrefix, ex.Message);
            throw new DataException("An error occurred while accessing the database.", ex);
        }
    }

    public async Task<IList<ApprovedSubmissionEntity>> GetApprovedSubmissionsWithAggregatedPomDataMyc(int periodYear, string includePackagingTypes, string includePackagingMaterials)
    {
        logger.LogInformation("{LogPrefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomDataMyc: Get approved submissions for period year {PeriodYear}, " +
            "including packaging types {IncludePackagingTypes} and including packaging materials {IncludePackagingMaterials}",
            _logPrefix, periodYear, includePackagingTypes, includePackagingMaterials);

        var sql = "EXECUTE dbo.sp_GetApprovedSubmissionsMyc @PeriodYear, @IncludePackagingTypes, @IncludePackagingMaterials";
        logger.LogInformation("{LogPrefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomDataMyc: executing query {Sql}", _logPrefix, sql);

        try
        {
            databaseTimeoutService.SetCommandTimeout(accountsDbContext, 320);
            var paginatedResponse = await accountsDbContext.RunSqlAsync<ApprovedSubmissionEntity>(sql,
                new SqlParameter("@PeriodYear", SqlDbType.VarChar) { Value = periodYear.ToString() },
                new SqlParameter("@IncludePackagingTypes", SqlDbType.VarChar) { Value = includePackagingTypes ?? (object)DBNull.Value },
                new SqlParameter("@IncludePackagingMaterials", SqlDbType.VarChar) { Value = includePackagingMaterials ?? (object)DBNull.Value });

            logger.LogInformation("{LogPrefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomDataMyc: Response received from stored procedure", _logPrefix);
            return paginatedResponse;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "{LogPrefix}: SubmissionsService - GetApprovedSubmissionsWithAggregatedPomDataMyc: An error occurred while accessing the database. - {Ex}", _logPrefix, ex.Message);
            throw new DataException("An error occurred while accessing the database.", ex);
        }
    }

    public async Task<PaginatedResponse<OrganisationRegistrationSummaryDto>?> GetOrganisationRegistrationSubmissionSummaries(int NationId, OrganisationRegistrationFilterRequest filter)
    {
        logger.LogInformation("{Logprefix}: SubmissionsService - GetOrganisationRegistrationSubmissionSummaries: Get OrganisationRegistrationSubmissions for given request", _logPrefix);
        var sql = "EXECUTE dbo.sp_FilterAndPaginateOrganisationRegistrationSummaries_resub @OrganisationNameCommaSeparated, @OrganisationReferenceCommaSeparated, @SubmissionYearsCommaSeparated, @StatusesCommaSeparated, @ResubmissionStatusesCommaSeparated, @OrganisationTypeCommaSeparated, @NationId, @AppRefNumbersCommaSeparated, @PageSize, @PageNumber";

        SqlParameter[] sqlParameters = filter.ToProcParams();

        sqlParameters =
        [
            .. sqlParameters,
            new SqlParameter("@NationId", SqlDbType.Int) { Value = NationId },
        ];

        try
        {
            var dataset = await accountsDbContext.RunSqlAsync<OrganisationRegistrationSummaryDataRow>(sql, sqlParameters);
            var itemsCount = dataset.FirstOrDefault()?.TotalItems ?? 0;

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

        var useLateFeeSp = bool.TryParse(config["FeatureManagement:QueriedSubmission_LateFee_StoredProcedure"], out var result) && result;

        var sql = useLateFeeSp
            ? "dbo.sp_FetchOrganisationRegistrationSubmissionDetails_resub_LateFee"
            : "dbo.sp_FetchOrganisationRegistrationSubmissionDetails_resub";

        var sqlParameters = request.ToProcParams();

        try
        {
#pragma warning disable S125
            //databaseTimeoutService.SetCommandTimeout(accountsDbContext, 120);
#pragma warning restore S125
            var dbSet = await accountsDbContext.RunSpCommandAsync<OrganisationRegistrationDetailsDto>(sql, logger, _logPrefix, sqlParameters);

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

    public async Task<PomResubmissionPaycalParametersDto?> GetResubmissionPaycalParameters(string sanitisedSubmissionId, string? sanitisedComplianceSchemeId)
    {
        logger.LogInformation("{Logprefix}: SubmissionsService - GetResubmissionPaycalParameters: Get sp_PomResubmissionPaycalParameters for given submission {SubmissionId}/{ComplianceSchemeId}", _logPrefix, sanitisedSubmissionId, sanitisedComplianceSchemeId);
        var sql = "[dbo].[sp_PomResubmissionPaycalParameters]";

        SqlParameter[] sqlParameters =
        {
            new("@SubmissionId", SqlDbType.NVarChar,40)
            {
                Value = sanitisedSubmissionId ?? (object)DBNull.Value
            },
            new ("@ComplianceSchemeId", SqlDbType.NVarChar, 40)
            {
                Value = sanitisedComplianceSchemeId ?? (object)DBNull.Value
            }
        };

        try
        {
            var dbSet = await accountsDbContext.RunSpCommandAsync<PomResubmissionPaycalParametersDto>(sql, logger, _logPrefix, sqlParameters);
            logger.LogInformation("{Logprefix}: SubmissionsService - GetResubmissionPaycalParameters: Get GetResubmissionPaycalParameters Query Response {Dataset}", _logPrefix, JsonConvert.SerializeObject(dbSet));

            return dbSet.FirstOrDefault();
        }
        catch (SqlException ex) when (ex.Number == -2)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsService - GetResubmissionPaycalParameters: A Timeout error occurred while accessing the database. - {Ex}", _logPrefix, ex.Message);
            throw new TimeoutException("The request timed out while accessing the database.", ex);
        }
        catch (SqlException ex)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsService - GetResubmissionPaycalParameters: An error occurred while accessing the database. - {Ex}", _logPrefix, ex.Message);
            throw new DataException("An exception occurred when executing query.", ex);
        }
    }

    public async Task<bool?> IsCosmosDataAvailable(string? sanitisedSubmissionId, string? sanitisedFileId)
    {
        logger.LogInformation("{Logprefix}: SubmissionsService - IsCosmosDataAvailable: Get sp_CheckForCosmosData for given submission/file {SubmissionId}/{FileId}", _logPrefix, sanitisedSubmissionId, sanitisedFileId);
        var sql = "[dbo].[sp_CheckForCosmosData]";

        SqlParameter[] sqlParameters =
        {
            new("@SubmissionId", SqlDbType.NVarChar,40)
            {
                Value = sanitisedSubmissionId ?? (object)DBNull.Value
            },
            new ("@FileId", SqlDbType.NVarChar, 40)
            {
                Value = sanitisedFileId ?? (object)DBNull.Value
            }
        };

        try
        {
            var dbSet = await accountsDbContext.RunSpCommandAsync<CosmosSyncInfo>(sql, logger, _logPrefix, sqlParameters);
            logger.LogInformation("{Logprefix}: SubmissionsService - GetResubmissionPaycalParameters: Get GetResubmissionPaycalParameters Query Response {Dataset}", _logPrefix, JsonConvert.SerializeObject(dbSet));

            if (dbSet.Count > 0)
            {
                return dbSet[0].IsSynced;
            }

            return false;
        }
        catch (SqlException ex) when (ex.Number == -2)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsService - GetResubmissionPaycalParameters: A Timeout error occurred while accessing the database. - {Ex}", _logPrefix, ex.Message);
            throw new TimeoutException("The request timed out while accessing the database.", ex);
        }
        catch (SqlException ex)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsService - GetResubmissionPaycalParameters: An error occurred while accessing the database. - {Ex}", _logPrefix, ex.Message);
            throw new DataException("An exception occurred when executing query.", ex);
        }
    }

    public async Task<bool> IsPOMResubmissionDataSynchronised(string sanitisedFileId)
    {
        logger.LogInformation("{Logprefix}: SubmissionsService - IsPOMResubmissionDataSynchronised: Get sp_IsPOMResubmissionDataSynchronised for given file {FileId}", _logPrefix, sanitisedFileId);
        var sql = "[dbo].[sp_IsPOMResubmissionSynchronised]";

        SqlParameter[] sqlParameters =
        [
            new ("@FileId", SqlDbType.NVarChar, 40)
            {
                Value = sanitisedFileId
            }
        ];

        try
        {
            var dbSet = await accountsDbContext.RunSpCommandAsync<CosmosSyncInfo>(sql, logger, _logPrefix, sqlParameters);
            logger.LogInformation("{Logprefix}: SubmissionsService - IsPOMResubmissionDataSynchronised: Get sp_IsPOMResubmissionSynchronised Query Response {Dataset}", _logPrefix, JsonConvert.SerializeObject(dbSet));

            if (dbSet.Count > 0)
            {
                return dbSet[0].IsSynced ?? false;
            }

            return false;
        }
        catch (SqlException ex) when (ex.Number == -2)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsService - IsPOMResubmissionDataSynchronised: A Timeout error occurred while accessing the database. - {Ex}", _logPrefix, ex.Message);
            throw new TimeoutException("The request timed out while accessing the database.", ex);
        }
        catch (SqlException ex)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsService - IsPOMResubmissionDataSynchronised: An error occurred while accessing the database. - {Ex}", _logPrefix, ex.Message);
            throw new DataException("An exception occurred when executing query.", ex);
        }
    }

    public async Task<string> GetActualSubmissionPeriod(string sanitisedSubmissionId, string submissionPeriod)
    {
        var sql = "[apps].[sp_GetActualSubmissionPeriod]";

        SqlParameter[] sqlParameters =
         [
             new ("@SubmissionId", SqlDbType.NVarChar, 50) { Value = sanitisedSubmissionId },
             new ("@SubmissionPeriod", SqlDbType.NVarChar, 50) { Value = submissionPeriod },

         ];
        logger.LogInformation("{LogPrefix}: SubmissionsService - {MethodName}: query {Query} parameters {Parameters}", _logPrefix, nameof(GetActualSubmissionPeriod), sql, JsonConvert.SerializeObject(sqlParameters));

        var response = await accountsDbContext.RunSpCommandAsync<ActualSubmissionPeriodInfo>(sql, logger, _logPrefix, sqlParameters);
        if (response is not null && response.Count > 0)
        {
            return response[0].ActualSubmissionPeriod ?? submissionPeriod;
        }

        return submissionPeriod;
    }
}
