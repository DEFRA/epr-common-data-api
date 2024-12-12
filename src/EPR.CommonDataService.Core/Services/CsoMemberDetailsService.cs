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
        IList<CsoMemberDetailsModel> response;
        try
        {
            const string Sql = "EXECUTE dbo.sp_GetCsoMemberDetailsByOrganisationId @OrganisationId";

            response = await synapseContext.RunSqlAsync<CsoMemberDetailsModel>(Sql, new SqlParameter("@OrganisationId", SqlDbType.Int) { Value = organisationId });
        }
        catch
        {
            return null;
        }

        return response.Select(r => new GetCsoMemberDetailsResponse
        {
            IsOnlineMarketplace = r.IsOnlineMarketplace,
            MemberId = Convert.ToString(r.MemberId),
            MemberType = ProducerSizeMapper.Map(r.MemberType),
            NumberOfSubsidiaries = r.NumberOfSubsidiaries,
            NumberOfSubsidiariesBeingOnlineMarketPlace = r.NumberOfSubsidiariesBeingOnlineMarketPlace
        }).ToArray();
    }
}