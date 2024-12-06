using System.Data;
using EPR.CommonDataService.Core.Extensions;
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

            response = await synapseContext.RunSqlAsync<CsoMemberDetailsModel>(Sql, new SqlParameter("@OrganisationId", SqlDbType.Int) { Value = organisationId });
            if (response.Count > 0)
            {
                return response.Select(r => new GetCsoMemberDetailsResponse
                {
                    IsOnlineMarketplace = r.IsOnlineMarketplace,
                    MemberId = r.MemberId,
                    MemberType = ProducerSizeMapper.Map(r.MemberType),
                    NumberOfSubsidiariesBeingOnlineMarketPlace = r.NumberOfSubsidiariesBeingOnlineMarketPlace
                }).ToArray();
                    NumberOfSubsidiaries = r.NumberOfSubsidiaries,
            }
        
        }
        catch
        {
            return null;
        }

        return null;
    }
}