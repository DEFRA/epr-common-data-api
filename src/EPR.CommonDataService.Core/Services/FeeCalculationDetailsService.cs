using System.Data;
using EPR.CommonDataService.Core.Mapper;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;

namespace EPR.CommonDataService.Core.Services;

public interface IFeeCalculationDetailsService
{
    Task<FeeCalculationDetails[]?> GetFeeCalculationDetails(Guid fileId);
}

public class FeeCalculationDetailsService(
    SynapseContext synapseContext)
    : IFeeCalculationDetailsService
{
    public async Task<FeeCalculationDetails[]?> GetFeeCalculationDetails(Guid fileId)
    {
        try
        {
            const string Sql = "EXECUTE dbo.sp_GetFeeCalculationDetails @fileId";
            var dbResponse = await synapseContext.RunSqlAsync<FeeCalculationDetailsModel>(Sql, new SqlParameter("@fileId", SqlDbType.VarChar, 40) { Value = fileId.ToString("D") });
            if (dbResponse.Count > 0)
            {
                var response = dbResponse.Select(resp => new FeeCalculationDetails
                {
                    IsOnlineMarketplace = resp.IsOnlineMarketplace,
                    NumberOfSubsidiaries = resp.NumberOfSubsidiaries,
                    NumberOfSubsidiariesBeingOnlineMarketPlace = resp.NumberOfSubsidiariesBeingOnlineMarketPlace,
                    OrganisationSize = OrganisationSizeMapper.Map(resp.OrganisationSize),
                    OrganisationId = resp.OrganisationId.ToString()
                }).ToArray();

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