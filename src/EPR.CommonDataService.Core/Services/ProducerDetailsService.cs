using System.Data;
using EPR.CommonDataService.Core.Mapper;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;

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
            var dbResponse = await synapseContext.RunSqlAsync<ProducerDetailsModel>(Sql, new SqlParameter("@OrganisationId", SqlDbType.Int) { Value = organisationId });
            if (dbResponse.Count > 0)
            {
                response = new GetProducerDetailsResponse()
                {
                    IsOnlineMarketplace = dbResponse[0].IsOnlineMarketplace,
                    NumberOfSubsidiaries = dbResponse[0].NumberOfSubsidiaries,
                    NumberOfSubsidiariesBeingOnlineMarketPlace = dbResponse[0].NumberOfSubsidiariesBeingOnlineMarketPlace,
                    ProducerSize = ProducerSizeMapper.Map(dbResponse[0].ProducerSize)                   
                };
                 
                return response;
            }
        }
        catch 
        {
            return null;
        }

        return null;
    }
}