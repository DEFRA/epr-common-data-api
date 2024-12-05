using System.Data;
using EPR.CommonDataService.Core.Extensions;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;
using static EPR.CommonDataService.Core.Mapper.ProducerDetailsService;

namespace EPR.CommonDataService.Core.Services;

public interface IProducerDetailsService
{
    Task<GetProducerDetailsResponse?> GetProducerDetails(int organisationId);
}

public  class ProducerDetailsService(
    SynapseContext synapseContext)
    : IProducerDetailsService
{
    public async Task<GetProducerDetailsResponse?> GetProducerDetails(int organisationId)
    {
        GetProducerDetailsResponse response;
        
        try
        {
            const string Sql = "EXECUTE dbo.sp_GetProducerDetailsByOrganisationId @OrganisationId";
            var param = new SqlParameter("@OrganisationId", SqlDbType.Int) { Value = organisationId };

            SqlParameter[] sqlParameters = [param];

            var dbresponse = await synapseContext.RunSqlAsync<ProducerDetailsModel>(Sql, sqlParameters);
            if (dbresponse.Count > 0)
            {
                response = new GetProducerDetailsResponse()
                {
                    IsOnlineMarketplace = dbresponse[0].IsOnlineMarketplace,
                    NumberOfSubsidiaries = dbresponse[0].NumberOfSubsidiaries,
                    NumberOfSubsidiariesBeingOnlineMarketPlace = dbresponse[0].NumberOfSubsidiariesBeingOnlineMarketPlace,
                    ProducerSize = ProducerSizeMapper.Map(dbresponse[0].ProducerSize),
                   
                };
                 
                return response;
            }
        }
        catch (Exception ex)
        {
            return null;
        }

        return null;
    }
}