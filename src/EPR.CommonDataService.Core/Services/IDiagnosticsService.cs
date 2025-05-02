using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace EPR.CommonDataService.Core.Services
{
    public interface IDiagnosticsService
    {
        Task<ComplianceSchemeInfo?> GetComplianceScheme(string? SubmissionId, string? ComplianceSchemeId);
        Task<IList<ComplianceSchemeMembers>?> GetComplianceSchemeMembersById(string? SubmissionId, string? ComplianceSchemeId);
    }
}
