using System.Data;
using EPR.CommonDataService.Core.Extensions;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;

namespace EPR.CommonDataService.Core.Services;

public interface IProducerDetailsService
{
    Task<GetProducerDetailsResponse?> GetProducerDetails(int organisationId);
}

public class ProducerDetailsService(
    SynapseContext synapseContext)
    : IProducerDetailsService
{

    public async Task<GetProducerDetailsResponse?> GetProducerDetails(int organisationId)
    {
        if (StoredProcedureExtensions.ReturnFakeData)
            return new GetProducerDetailsResponse { OrganisationId = organisationId, ProducerSize = "Large", NumberOfSubsidiariesBeingOnlineMarketPlace = 29, IsOnlineMarketplace = true, NumberOfSubsidiaries = 54 };

        IList<ProducerDetailsModel> response;
        try
        {
            const string Sql = "EXECUTE apps.sp_GetProducerDetails @OrganisationId";

            var sqlParameters = new List<SqlParameter>
            {
                new ("@OrganisationId", SqlDbType.Int) { Value = organisationId }
            };

            response = await synapseContext.RunSqlAsync<ProducerDetailsModel>(Sql, sqlParameters);
        }
        catch
        {
            return null;
        }

        var firstItem = response.FirstOrDefault();

        return
            firstItem is null ? null :

            new GetProducerDetailsResponse
            {
                ProducerSize = firstItem.ProducerSize,
                OrganisationId = firstItem.OrganisationId
            };
    }

}