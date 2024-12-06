using System.Data;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;
using static EPR.CommonDataService.Core.Mapper.ProducerDetailsService;

namespace EPR.CommonDataService.Core.Services;

public interface ICsoMemberDetailsService
{
    Task<GetCsoMemberDetailsResponse[]?> GetCsoMemberDetails(int organisationId);
}

public class CsoMemberDetailsService(
    SynapseContext synapseContext)
    : ICsoMemberDetailsService
{ 
    public async Task<GetCsoMemberDetailsResponse[]?> GetCsoMemberDetails(int organisationId)
    {
        try
        {
            const string Sql = "EXECUTE dbo.sp_GetCsoMemberDetailsByOrganisationId @OrganisationId";

            var dbresponse = await synapseContext.RunSqlAsync<CsoMemberDetailsModel>(Sql, new SqlParameter("@OrganisationId", SqlDbType.Int) { Value = organisationId });
            if (dbresponse.Count > 0)
            {
                return dbresponse.Select(r => new GetCsoMemberDetailsResponse
                {
                    IsOnlineMarketplace = r.IsOnlineMarketplace,
                    MemberId = r.MemberId,
                    MemberType = ProducerSizeMapper.Map(r.MemberType),
                    NumberOfSubsidiariesBeingOnlineMarketPlace = r.NumberOfSubsidiariesBeingOnlineMarketPlace,
                    NumberOfSubsidiaries = r.NumberOfSubsidiaries,
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