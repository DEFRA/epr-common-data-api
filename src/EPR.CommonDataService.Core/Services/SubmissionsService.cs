using Azure.Core;
using EPR.CommonDataService.Core.Extensions;
using EPR.CommonDataService.Core.Models;
using EPR.CommonDataService.Core.Models.Requests;

using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.SqlServer.Query.Internal;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using System.Data;
using System.Globalization;

// ReSharper disable CoVariantArrayConversion

namespace EPR.CommonDataService.Core.Services;

public class SubmissionsService(IDbContextFactory<SynapseContext> dbFactory, /*SynapseContext _synapseContext, */IDatabaseTimeoutService databaseTimeoutService, ILogger<SubmissionsService> logger, IConfiguration config) : ISubmissionsService
{
    private readonly string? _logPrefix = string.IsNullOrEmpty(config["LogPrefix"]) ? "[EPR.CommonDataService]" : config["LogPrefix"];
    private readonly SynapseContext _synapseContext = dbFactory.CreateDbContext();

    public async Task<PaginatedResponse<PomSubmissionSummary>> GetSubmissionPomSummaries<T>(SubmissionsSummariesRequest<T> request)
    {
        var sql = "EXECUTE [apps].[sp_FilterAndPaginateSubmissionsSummaries_resub] @OrganisationName, @OrganisationReference, @RegulatorUserId, @StatusesCommaSeperated, @OrganisationType, @PageSize, @PageNumber, @DecisionsDelta, @SubmissionYearsCommaSeperated, @SubmissionPeriodsCommaSeperated, @ActualSubmissionPeriodsCommaSeperated";

        var sqlParameters = request.ToProcParams();
        logger.LogInformation("{LogPrefix}: SubmissionsService - GetSubmissionPomSummaries: query {Query} parameters {Parameters}", _logPrefix, sql, JsonConvert.SerializeObject(sqlParameters));

        var response = await _synapseContext.RunSqlAsync<PomSubmissionSummaryRow>(sql, sqlParameters);
        var itemsCount = response.FirstOrDefault()?.TotalItems ?? 0;
        var paginatedResponse = response.ToPaginatedResponse<PomSubmissionSummaryRow, T, PomSubmissionSummary>(request, itemsCount);

        return paginatedResponse;
    }

    public async Task<PaginatedResponse<RegistrationSubmissionSummary>> GetSubmissionRegistrationSummaries<T>(SubmissionsSummariesRequest<T> request)
    {
        var sql = "EXECUTE apps.sp_FilterAndPaginateRegistrationsSummaries @OrganisationName, @OrganisationReference, @RegulatorUserId, @StatusesCommaSeperated, @OrganisationType, @PageSize, @PageNumber, @DecisionsDelta, @SubmissionYearsCommaSeperated, @ActualSubmissionPeriodsCommaSeperated";
        var sqlParameters = request.ToProcParams();
        logger.LogInformation("{LogPrefix}: SubmissionsService - GetSubmissionRegistrationSummaries: query {Query} parameters {Parameters}", _logPrefix, sql, JsonConvert.SerializeObject(sqlParameters));

        var response = await _synapseContext.RunSqlAsync<RegistrationsSubmissionSummaryRow>(sql, sqlParameters);
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
            var paginatedResponse = await _synapseContext.RunSqlAsync<ApprovedSubmissionEntity>(sql,
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
        var sql = "EXECUTE dbo.sp_FilterAndPaginateOrganisationRegistrationSummaries_resub @OrganisationNameCommaSeparated, @OrganisationReferenceCommaSeparated, @SubmissionYearsCommaSeparated, @StatusesCommaSeparated, @ResubmissionStatusesCommaSeparated, @OrganisationTypeCommaSeparated, @NationId, @AppRefNumbersCommaSeparated, @PageSize, @PageNumber";

        SqlParameter[] sqlParameters = filter.ToProcParams();

        sqlParameters =
        [
            .. sqlParameters,
            new SqlParameter("@NationId", SqlDbType.Int) { Value = NationId },
        ];

        try
        {
            var dataset = await _synapseContext.RunSqlAsync<OrganisationRegistrationSummaryDataRow>(sql, sqlParameters);
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
        var sql = "dbo.sp_FetchOrganisationRegistrationSubmissionDetails_resub";
        var sqlParameters = request.ToProcParams();

        try
        {
            var dbSet = await _synapseContext.RunSpCommandAsync<OrganisationRegistrationDetailsDto>(sql, logger, _logPrefix, sqlParameters);

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

    public async Task<OrganisationRegistrationDetailsDto?> GetOrgRegistrationSubmissionDetails_WithSeparatedCSO(OrganisationRegistrationDetailRequest request)
    {
        logger.LogInformation("{Logprefix}: SubmissionsService - GetOrgRegistrationSubmissionDetails_WithSeparatedCSO: Get OrganisationRegistrationSubmissionDetails for given request {Request}", _logPrefix, JsonConvert.SerializeObject(request));
        var sql1 = "dbo.sp_FetchOrganisationRegistrationSubmissionDetails_resub_nocso";
        var sql2 = "dbo.sp_FetchOrganisationRegistrationCSMemberDetails";

        var sqlParameters1 = request.ToProcParams();
        var sqlParameters2 = request.ToProcParams();

        sqlParameters2 = [.. sqlParameters2.Append(new SqlParameter("@ForProducer", false))];

        try
        {
            var ctx1 = await dbFactory.CreateDbContextAsync();
            var ctx2 = await dbFactory.CreateDbContextAsync();
            // 1) Kick off both SP calls in parallel
            var detailsTask = ctx1
                .RunSpCommandAsync<OrganisationRegistrationDetailsDto>(sql1, logger, _logPrefix, sqlParameters1);

            var csoTask = ctx2
                .RunSpCommandAsync<OrganisationRegistrationCSODetailsDto>(sql2, logger, _logPrefix, sqlParameters2);

            // 2) As soon as csoTask completes, start GenerateCSOJson on its result
            var jsonTask = csoTask.ContinueWith(
                t => GenerateCSOJson(t.Result),
                TaskContinuationOptions.OnlyOnRanToCompletion);

            // 3) Await both the details and the JSON generation
            await Task.WhenAll(detailsTask, jsonTask);

            // 4) Bundle results
            var details = detailsTask.Result;
            var dto = details.FirstOrDefault();
            if (dto != null)
            {
                dto.CSOJson = jsonTask.Result;
            }

            return dto;
        }
        catch (SqlException ex) when (ex.Number == -2)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsService - GetOrgRegistrationSubmissionDetails_WithSeparatedCSO: A Timeout error occurred while accessing the database. - {Ex}", _logPrefix, ex.Message);
            throw new TimeoutException("The request timed out while accessing the database.", ex);
        }
        catch (SqlException ex)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsService - GetOrgRegistrationSubmissionDetails_WithSeparatedCSO: An error occurred while accessing the database. - {Ex}", _logPrefix, ex.Message);
            throw new DataException("An exception occurred when executing query.", ex);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsService - GetOrgRegistrationSubmissionDetails_WithSeparatedCSO: An error occurred - {Ex}", _logPrefix, ex.Message);
            throw new DataException($"An exception occurred when processing tasks. {ex.Message}", ex);
        }
    }

    public static string GenerateCSOJson(IList<OrganisationRegistrationCSODetailsDto> csos)
    {
        if (csos == null || !csos.Any())
        {
            return "[]";
        }

        var shaped = csos.Select(c => new CSOMemberType
        {
            MemberId = c.ReferenceNumber.ToString(),
            MemberType = c.ProducerSize,
            IsOnlineMarketPlace = c.IsOnlineMarketPlace,
            NumberOfSubsidiaries = c.NumberOfSubsidiaries,
            NumberOfSubsidiariesOnlineMarketPlace = c.NumberOfSubsidiariesBeingOnlineMarketPlace,
            RelevantYear = c.RelevantYear,
            SubmittedDate = c.SubmittedDate,
            IsLateFeeApplicable = c.IsLateFeeApplicable,
            SubmissionPeriodDescription = c.SubmissionPeriod
        }).ToList();

        return JsonConvert.SerializeObject(
            shaped,
            new JsonSerializerSettings
            {
                NullValueHandling = NullValueHandling.Ignore,
                DateFormatString = "yyyy-MM-ddTHH:mm:ss.fffZ"
            }
        );
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
            var dbSet = await _synapseContext.RunSpCommandAsync<PomResubmissionPaycalParametersDto>(sql, logger, _logPrefix, sqlParameters);
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
            var dbSet = await _synapseContext.RunSpCommandAsync<CosmosSyncInfo>(sql, logger, _logPrefix, sqlParameters);
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
}