using System.Data;
using EPR.CommonDataService.Core.Mapper;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;

namespace EPR.CommonDataService.Core.Services;

public interface IRegistrationFeeCalculationDetailsService
{
    Task<RegistrationFeeCalculationDetails[]?> GetRegistrationFeeCalculationDetails(Guid fileId);
}

public class RegistrationFeeCalculationDetailsService(SynapseContext synapseContext)
    : IRegistrationFeeCalculationDetailsService
{
    public async Task<RegistrationFeeCalculationDetails[]?> GetRegistrationFeeCalculationDetails(Guid fileId)
    {
        try
        {
            const string Sql = "EXECUTE dbo.sp_GetRegistrationFeeCalculationDetails @fileId";
            var dbResponse = await synapseContext.RunSqlAsync<RegistrationFeeCalculationDetailsModel>(Sql, new SqlParameter("@fileId", SqlDbType.VarChar, 40) { Value = fileId.ToString("D") });
            if (dbResponse.Count > 0)
            {
                var response = dbResponse.Select(resp => new RegistrationFeeCalculationDetails
                {
                    IsOnlineMarketplace = resp.IsOnlineMarketplace,
                    IsNewJoiner = resp.IsNewJoiner,
                    NumberOfSubsidiaries = resp.NumberOfSubsidiaries,
                    NumberOfSubsidiariesBeingOnlineMarketPlace = resp.NumberOfSubsidiariesBeingOnlineMarketPlace,
                    NumberOfLateSubsidiaries = resp.NumberOfLateSubsidiaries,
                    OrganisationSize = OrganisationSizeMapper.Map(resp.OrganisationSize),
                    OrganisationId = resp.OrganisationId.ToString(),
                    NationId = resp.NationId
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