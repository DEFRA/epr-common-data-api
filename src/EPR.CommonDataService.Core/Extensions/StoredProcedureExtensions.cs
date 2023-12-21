using System.Data;
using EPR.CommonDataService.Core.Models.Requests;
using System.Text;
using System.Text.Json;
using Microsoft.Data.SqlClient;

namespace EPR.CommonDataService.Core.Extensions;

public static class StoredProcedureExtensions
{
    public static SqlParameter[] ToProcParams(this PomSubmissionsSummariesRequest request)
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
            }
        };

        return parameters.ToArray();
    }
}