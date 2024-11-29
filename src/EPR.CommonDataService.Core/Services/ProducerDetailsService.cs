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

public partial class ProducerDetailsService(
    SynapseContext synapseContext)
    : IProducerDetailsService
{
    public async Task<GetProducerDetailsResponse?> GetProducerDetails(int organisationId)
    {
        IList<ProducerDetailsModel> response;
        try
        {
            const string Sql = "EXECUTE apps.sp_GetProducerDetailsByOrganisationId @OrganisationId";

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
                ProducerSize = ProducerSizeMapper.Map(firstItem.ProducerSize),
                IsOnlineMarketplace = firstItem.IsOnlineMarketplace,
                NumberOfSubsidiaries = firstItem.NumberOfSubsidiaries,
                NumberOfSubsidiariesBeingOnlineMarketPlace = firstItem.NumberOfSubsidiariesBeingOnlineMarketPlace
            };
    }


}