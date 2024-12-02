using EPR.CommonDataService.Core.Models.Requests;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Text.Json;

namespace EPR.CommonDataService.Core.Extensions;

public static class StoredProcedureExtensions
{
    public static bool ReturnFakeData { get; set; } = true;

    public static SqlParameter[] ToProcParams(this OrganisationRegistrationDetailRequest request)
    {
        return
        [
            new ("@SubmissionId", SqlDbType.UniqueIdentifier)
            {
                Value = request.SubmissionId
            }
        ];
    }

    public static SqlParameter[] ToProcParams(this OrganisationRegistrationFilterRequest request)
    {
        return
        [
            new ("@OrganisationNameCommaSeparated", SqlDbType.NVarChar, 255)
            {
                Value = request.OrganisationNameCommaSeparated ?? (object)DBNull.Value
            },
            new ("@OrganisationReferenceCommaSeparated", SqlDbType.NVarChar, 255)
            {
                Value = request.OrganisationIDCommaSeparated ?? (object)DBNull.Value
            },
            new ("@SubmissionYearsCommaSeparated ", SqlDbType.NVarChar, 255)
            {
                Value = request.RelevantYearCommaSeparated ?? (object)DBNull.Value
            },
            new ("@StatusesCommaSeparated", SqlDbType.NVarChar, 255)
            {
                Value = request.SubmissionStatusCommaSeparated ?? (object)DBNull.Value
            },
            new ("@OrganisationTypeCommaSeparated", SqlDbType.NVarChar, 255)
            {
                Value = request.OrganisationTypesCommaSeparated ?? (object)DBNull.Value
            },
            new ("@AppRefNumbersCommaSeparated", SqlDbType.NVarChar, 2000)
            {
                Value = request.ApplicationReferenceNumbers ?? (object)DBNull.Value
            },
            new ("@PageSize", SqlDbType.Int) {
                Value = request.PageSize
            },
            new ("@PageNumber", SqlDbType.Int) {
                Value = request.PageNumber
            },
        ];
    }

    public static SqlParameter[] ToProcParams<T>(this SubmissionsSummariesRequest<T> request)
    {
        var parameters = new List<SqlParameter>
        {
            new ("@OrganisationName", SqlDbType.NVarChar, 255) {
                Value = request.OrganisationName ?? (object)DBNull.Value
            },
            new ("@OrganisationReference", SqlDbType.NVarChar, 255) {
                Value = request.OrganisationReference ?? (object)DBNull.Value
            },
            new ("@RegulatorUserId", SqlDbType.NVarChar, 50) {
                Value = request.UserId.ToString()
            },
            new ("@StatusesCommaSeperated", SqlDbType.NVarChar, 50) {
                Value = request.Statuses ?? (object)DBNull.Value
            },
            new ("@OrganisationType", SqlDbType.NVarChar, 50) {
                Value = request.OrganisationType ?? (object)DBNull.Value
            },
            new ("@PageSize", SqlDbType.Int) {
                Value = request.PageSize
            },
            new ("@PageNumber", SqlDbType.Int) {
                Value = request.PageNumber
            },
            new ("@DecisionsDelta", SqlDbType.NVarChar, -1) { // -1 for MAX
                Value = request.DecisionsDelta?.Length > 0
                    ? JsonSerializer.Serialize(request.DecisionsDelta)
                    : "[]"
            },
            new ("@SubmissionYearsCommaSeperated", SqlDbType.NVarChar, 1000) {
                Value = request.SubmissionYears ?? (object)DBNull.Value
            },
            new ("@SubmissionPeriodsCommaSeperated", SqlDbType.NVarChar, 1500) {
                Value = DBNull.Value
            },
            new ("@ActualSubmissionPeriodsCommaSeperated", SqlDbType.NVarChar, 1500) {
                Value = request.SubmissionPeriods ?? (object)DBNull.Value
            }
        };

        return parameters.ToArray();
    }
}