using System.Data;
using EPR.CommonDataService.Core.Extensions;
using EPR.CommonDataService.Core.Mapper;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;
using Microsoft.IdentityModel.Tokens;

namespace EPR.CommonDataService.Core.Services;

public interface ICsoMemberDetailsService
{
    Task<GetCsoMemberDetailsResponse[]?> GetCsoMemberDetails(int organisationId, string complianceSchemeId);
}

public class CsoMemberDetailsService(
    SynapseContext synapseContext)
    : ICsoMemberDetailsService
{
    public async Task<GetCsoMemberDetailsResponse[]?> GetCsoMemberDetails(int organisationId, string complianceSchemeId)
    {
        IList<CsoMemberDetailsModel> response;
        try
        {
            const string Sql = "EXECUTE dbo.sp_GetCsoMemberDetails @OrganisationId, @ComplianceSchemeId";

            response = await synapseContext.RunSqlAsync<CsoMemberDetailsModel>(Sql, 
                new SqlParameter("@OrganisationId", SqlDbType.Int) { Value = organisationId },
                 new SqlParameter("@ComplianceSchemeId", SqlDbType.NVarChar, 50) { Value = complianceSchemeId}
            );

            if (response.Count > 0)
            {
                return response.Select(r => new GetCsoMemberDetailsResponse
                {
                    IsOnlineMarketplace = r.IsOnlineMarketplace,
                    MemberId = Convert.ToString(r.MemberId),
                    MemberType = ProducerSizeMapper.Map(r.MemberType),
                    NumberOfSubsidiaries = r.NumberOfSubsidiaries,
                    NumberOfSubsidiariesBeingOnlineMarketPlace = r.NumberOfSubsidiariesBeingOnlineMarketPlace,
                    IsLateFeeApplicable = false,
                }).ToArray();
            }

        }
        catch
        {
            return null;
        }

        return null;
    }
}