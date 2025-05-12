using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.Controllers
{
    [ExcludeFromCodeCoverage]
    [Route("api/[controller]")]
    [ApiController]
    public class DiagnosticsController(IDiagnosticsService diagService, IOptions<ApiConfig> apiConfig, ILogger<SubmissionsController> logger, IConfiguration config) : ControllerBase
    {
        private readonly string? _logPrefix = string.IsNullOrEmpty(config["LogPrefix"]) ? "[EPR.CommonDataService]" : config["LogPrefix"];
        private readonly ApiConfig apiConfig = apiConfig.Value;

        [HttpGet("diag/CompSchemeById")]
        [Produces("application/json")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> GetComplianceSchemeInfo(string? SubmissionId, string? ComplianceSchemeId )
        {
            var objRet = await diagService.GetComplianceScheme(SubmissionId, ComplianceSchemeId);
            return Ok(objRet);
        }

        [HttpGet("diag/CompSchemeMembersById")]
        [Produces("application/json")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> GetComplianceSchemeMembers(string? SubmissionId, string? ComplianceSchemeId)
        {
            var objRet = await diagService.GetComplianceSchemeMembersById(SubmissionId, ComplianceSchemeId);
            return Ok(objRet);
        }
    }
}
