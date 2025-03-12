using System.Data;
using EPR.CommonDataService.Core.Mapper;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;

namespace EPR.CommonDataService.Core.Services;

public interface IProducerDetailsService
{
    Task<GetProducerDetailsResponse?> GetProducerDetails(int organisationId);
    Task<List<UpdatedProducersResponseModel>> GetUpdatedProducers(DateTime from, DateTime to);
}

public class ProducerDetailsService(
    SynapseContext synapseContext, ILogger<ProducerDetailsService> logger)
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
                    ProducerSize = ProducerSizeMapper.Map(dbResponse[0].ProducerSize)  ,
                    NationFromUploadedFile = dbResponse[0].NationFromUploadedFile,
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

    public async Task<List<UpdatedProducersResponseModel>> GetUpdatedProducers(DateTime from, DateTime to)
    {
        try
        {
            const string Sql = "EXECUTE [dbo].[sp_PRN_Delta_Extract] @From_Date, @To_Date";

            var parameters = new[]
                {
                new SqlParameter("@From_Date", SqlDbType.DateTime2) { Value = from },
                new SqlParameter("@To_Date", SqlDbType.DateTime2) { Value = to }
                };

            var dbResponse = await synapseContext.RunSqlAsync<UpdatedProducersResponseModel>(Sql, parameters);

            return dbResponse?.ToList() ?? new List<UpdatedProducersResponseModel>();
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error occurred in GetUpdatedProducers method. From: {FromDate}, To: {ToDate}", from, to);

            throw;
        }
    }
}