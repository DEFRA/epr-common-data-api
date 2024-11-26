using System.Data;
using EPR.CommonDataService.Core.Extensions;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;

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
        if (StoredProcedureExtensions.ReturnFakeData)
            return [new GetCsoMemberDetailsResponse { MemberId = "5678", MemberType = "Large", NumberOfSubsidiariesBeingOnlineMarketPlace = 39, IsOnlineMarketplace = true, NumberOfSubsidiaries = 64 }];

        IList<CsoMemberDetailsModel> response;
        try
        {
            const string Sql = "EXECUTE apps.sp_GetCsoMemberDetails @OrganisationId";

            var sqlParameters = new List<SqlParameter>
            {
                new ("@OrganisationId", SqlDbType.Int) { Value = organisationId }
            };

            response = await synapseContext.RunSqlAsync<CsoMemberDetailsModel>(Sql, sqlParameters);
        }
        catch
        {
            return null;
        }

        return response.Select(r => new GetCsoMemberDetailsResponse
        {
            IsOnlineMarketplace = r.IsOnlineMarketplace,
            MemberId = r.MemberId,
            MemberType = r.MemberType,
            NumberOfSubsidiaries = r.NumberOfSubsidiaries,
            NumberOfSubsidiariesBeingOnlineMarketPlace = r.NumberOfSubsidiariesBeingOnlineMarketPlace
        }).ToArray();
    }
}