using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics.CodeAnalysis;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace EPR.CommonDataService.Core.Services
{
    [ExcludeFromCodeCoverage]
    public class ComplianceSchemeIdResult
    {
        public string ComplianceSchemeId { get; set; }
    }

    [ExcludeFromCodeCoverage]
    public class ComplianceSchemeMembers
    {
        public string ComplianceSchemeId { get; set; }
        public string CSOExternalId { get; set; }
        public string CSOReference { get; set; }
        public string ReferenceNumber { get; set; }
        public string ExternalId { get; set; }
        public string OrganisationName { get; set; }
        public string SubmissionPeriod { get; set; }
        public int RelevantYear { get; set; }
        public string SubmittedDateTime { get; set; }
        public bool IsLateFeeApplicable { get; set; }
        public string leaver_code { get; set; }
        public string leaver_date { get; set; }
        public string joiner_date { get; set; }
        public string organisation_change_reason { get; set; }
        public string FileName { get; set; }
    }

    [ExcludeFromCodeCoverage]
    public class ComplianceSchemeInfo
    {
        public int id { get; set; }
        public string Name { get; set; }
        public string ExternalId { get; set; }
        public string CreatedOn { get; set; }
        public string LastUploadedOn { get; set; }
        public bool IsDeleted { get; set; }
        public string CompaniesHouseNumber { get; set; }
        public int NationId { get; set; }
        public IList<ComplianceSchemeMembers> Members { get; set; }
        public IList<CosmosUploadInfo> Uploads { get; set; }
    }

    [ExcludeFromCodeCoverage]
    public class CosmosUploadInfo
    {
        public string? SubmissionId { get; set; }
        public string? FileId { get; set; }
        public string? UserId { get; set; }
        public string? BlobName { get; set; }
        public string? BlobContainerName { get; set; }
        public string? FileType { get; set; }
        public string? Created { get; set; } // Consider changing this to DateTime if the string represents a datetime
        public string? OriginalFileName { get; set; }
        public string? RegistrationSetId { get; set; }
        public string? OrganisationId { get; set; }
        public string? DataSourceType { get; set; }
        public string? SubmissionPeriod { get; set; }
        public bool? IsSubmitted { get; set; }
        public string? SubmissionType { get; set; }
        public string? ComplianceSchemeId { get; set; }
        public string? TargetDirectoryName { get; set; }
        public string? TargetContainerName { get; set; }
        public string? SourceContainerName { get; set; }
        public string? FileName { get; set; }
        public DateTime? LoadTimestamp { get; set; }
    }

    [ExcludeFromCodeCoverage]
    public class DiagnosticsService(SynapseContext accountsDbContext, IDatabaseTimeoutService databaseTimeoutService, ILogger<SubmissionsService> logger, IConfiguration config) : IDiagnosticsService
    {
        private readonly string? _logPrefix = string.IsNullOrEmpty(config["LogPrefix"]) ? "[EPR.CommonDataService]" : config["LogPrefix"];

        public async Task<ComplianceSchemeInfo?> GetComplianceScheme(string? SubmissionId, string? ComplianceSchemeId)
        {
            var compSchemeId = "";

            if (!string.IsNullOrWhiteSpace(SubmissionId))
            {
                compSchemeId = await GetComplianceIdFromSubId(SubmissionId);
            }
            else
            {
                compSchemeId = ComplianceSchemeId;
            }

            if (!string.IsNullOrWhiteSpace(compSchemeId))
            {
                var sql = "select * from rpd.ComplianceSchemes where ExternalId = @ComplianceSchemeId";
                SqlParameter[] parameters = [new SqlParameter("@ComplianceSchemeId", System.Data.SqlDbType.NVarChar, 50) { Value = compSchemeId }];

                var dataset = await accountsDbContext.RunSQLCommandAsync<ComplianceSchemeInfo>(sql, logger, _logPrefix, parameters);

                var compScheme = dataset.FirstOrDefault();

                if ( null != compScheme)
                {
                    compScheme.Members = await GetComplianceSchemeMembersById(null, compSchemeId);
                    compScheme.Uploads = await GetComplianceSchemeUploads(compSchemeId);

                    return compScheme;
                }
            }

            return default;
        }

        public async Task<IList<ComplianceSchemeMembers>?> GetComplianceSchemeMembersById(string? SubmissionId, string? ComplianceSchemeId)
        {
            var compSchemeId = "";

            if (!string.IsNullOrWhiteSpace(SubmissionId))
            {
                compSchemeId = await GetComplianceIdFromSubId(SubmissionId);
            }
            else
            {
                compSchemeId = ComplianceSchemeId.ToString();
            }

            if (!string.IsNullOrWhiteSpace(compSchemeId))
            {
                var sql = "select * from dbo.v_ComplianceSchemeMembers_Resub where ComplianceSchemeId = @ComplianceSchemeId";
                SqlParameter[] parameters = [new SqlParameter("@ComplianceSchemeId", System.Data.SqlDbType.NVarChar, 50) { Value = compSchemeId }];

                var dataset = await accountsDbContext.RunSQLCommandAsync<ComplianceSchemeMembers>(sql, logger, _logPrefix, parameters);

                return dataset;
            }

            return default;
        }

        private async Task<string> GetComplianceIdFromSubId(string SubmissionId)
        {
            var compSchemeId = "";

            var sql = "select ComplianceSchemeId from rpd.Submissions where SubmissionId = @SubmissionId";
            SqlParameter[] parameters = [new SqlParameter("@SubmissionId", System.Data.SqlDbType.NVarChar, 50) { Value = SubmissionId }];

            var dataset = await accountsDbContext.RunSQLCommandAsync<ComplianceSchemeIdResult>(sql, logger, _logPrefix, parameters);

            var items = dataset.FirstOrDefault();
            if (items != null)
            {
                compSchemeId = items.ComplianceSchemeId;
            }

            return compSchemeId;
        }

        private async Task<IList<CosmosUploadInfo>> GetComplianceSchemeUploads(string complianceSchemeId)
        {
            if (!string.IsNullOrWhiteSpace(complianceSchemeId))
            {
                string sql = "select * from rpd.cosmos_file_metadata where ComplianceSchemeId = @ComplianceSchemeId order by Created desc, load_ts desc";

                SqlParameter[] parameters = [new SqlParameter("@ComplianceSchemeId", System.Data.SqlDbType.NVarChar, 50) { Value = complianceSchemeId }];

                var dataset = await accountsDbContext.RunSQLCommandAsync<CosmosUploadInfo>(sql, logger, _logPrefix, parameters);

                return dataset;
            }

            return [];
        }
    }
}
