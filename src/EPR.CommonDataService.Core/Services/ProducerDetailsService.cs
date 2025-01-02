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
    Task<List<UpdatedProducersResponse>> GetUpdatedProducers(DateTime from, DateTime to);
}

public class ProducerDetailsService(
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

    public async Task<List<UpdatedProducersResponse>> GetUpdatedProducers(DateTime from, DateTime to)
    {
        var organisations = new List<UpdatedProducersResponse>();
        try
        {
            const string Sql = "EXECUTE dbo.sp_Producerdetla_Test";

            var fromDateParam = new SqlParameter("@FromDate", SqlDbType.DateTime)
            {
                Value = from
            };

            var toDateParam = new SqlParameter("@ToDate", SqlDbType.DateTime)
            {
                Value = to
            };

            var dbResponse = await synapseContext.RunSqlAsync<List<UpdatedProducersResponse>>(Sql, fromDateParam, toDateParam);
            if (dbResponse != null && dbResponse.Count > 0)
            {
                organisations = (List<UpdatedProducersResponse>)dbResponse;
            }
        }
        catch
        {
            return null;
        }
        return organisations;
    }
}