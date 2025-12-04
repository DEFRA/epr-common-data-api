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
        return await GetUpdatedProducersInternal<UpdatedProducersResponseModel>(
            "sp_PRN_Delta_Extract",
            from,
            to,
            nameof(GetUpdatedProducers));
    }

    public async Task<List<UpdatedProducersResponseModelV2>> GetUpdatedProducersV2(DateTime from, DateTime to)
    {
        return await GetUpdatedProducersInternal<UpdatedProducersResponseModelV2>(
            "sp_Organisations_Delta_Extract",
            from,
            to,
            nameof(GetUpdatedProducersV2));
    }

    private async Task<List<T>> GetUpdatedProducersInternal<T>(
        string storedProcedureName,
        DateTime from,
        DateTime to,
        string methodName) where T : class
    {
        try
        {
            var sql = $"EXECUTE [dbo].[{storedProcedureName}] @From_Date, @To_Date";

            var parameters = new[]
            {
                new SqlParameter("@From_Date", SqlDbType.DateTime2) { Value = from },
                new SqlParameter("@To_Date", SqlDbType.DateTime2) { Value = to }
            };

            var dbResponse = await synapseContext.RunSqlAsync<T>(sql, parameters);

            return dbResponse?.ToList() ?? new List<T>();
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error occurred in {MethodName} method. From: {FromDate}, To: {ToDate}", methodName, from, to);

            throw;
        }
    }
}