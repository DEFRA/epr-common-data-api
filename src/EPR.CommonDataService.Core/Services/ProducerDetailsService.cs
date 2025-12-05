using System.Data;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;

namespace EPR.CommonDataService.Core.Services;

public interface IProducerDetailsService
{
    Task<List<UpdatedProducersResponseModel>> GetUpdatedProducers(DateTime from, DateTime to);
    Task<List<UpdatedProducersResponseModelV2>> GetUpdatedProducersV2(DateTime from, DateTime to);
}

public class ProducerDetailsService(
    SynapseContext synapseContext, ILogger<ProducerDetailsService> logger)
    : IProducerDetailsService
{
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

    public async Task<List<UpdatedProducersResponseModelV2>> GetUpdatedProducersV2(DateTime from, DateTime to)
    {
        try
        {
            const string Sql = "EXECUTE [dbo].[sp_Organisations_Delta_Extract] @From_Date, @To_Date";

            var parameters = new[]
            {
                new SqlParameter("@From_Date", SqlDbType.DateTime2) { Value = from },
                new SqlParameter("@To_Date", SqlDbType.DateTime2) { Value = to }
            };

            var dbResponse = await synapseContext.RunSqlAsync<UpdatedProducersResponseModelV2>(Sql, parameters);

            return dbResponse?.ToList() ?? new List<UpdatedProducersResponseModelV2>();
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error occurred in GetUpdatedProducersV2 method. From: {FromDate}, To: {ToDate}", from, to);

            throw;
        }
    }
}