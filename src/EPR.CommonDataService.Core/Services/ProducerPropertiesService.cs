using System.Data;
using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;

namespace EPR.CommonDataService.Core.Services;

public interface IProducerPropertiesService
{
    Task<GetProducerSizeResponse?> GetProducerSize(GetProducerSizeRequest request);
}

public class ProducerPropertiesService(SynapseContext synapseContext) : IProducerPropertiesService
{

    public async Task<GetProducerSizeResponse?> GetProducerSize(GetProducerSizeRequest request)
    {
        IList<ProducerPropertiesModel> response;
        try
        {
            const string Sql = "EXECUTE apps.sp_GetProducerProperties @OrganisationId";

            var sqlParameters = new List<SqlParameter>
            {
                new ("@OrganisationId", SqlDbType.UniqueIdentifier, 255) {
                    Value = request.OrganisationId
                }
            };

            response = await synapseContext.RunSqlAsync<ProducerPropertiesModel>(Sql, sqlParameters);
        }
        catch
        {
            return null;
        }

        var firstItem = response.FirstOrDefault();

        return
            firstItem is null ? null :

            new GetProducerSizeResponse
            {
                ProducerSize = firstItem.ProducerSize,
                OrganisationId = firstItem.OrganisationId
            };
    }

}