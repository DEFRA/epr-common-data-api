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

public  class ProducerDetailsService(
    SynapseContext synapseContext)
    : IProducerDetailsService
{
    public async Task<GetProducerDetailsResponse?> GetProducerDetails(int organisationId)
    {
        IList<ProducerDetailsModel> response;
        try
        {
            const string Sql = "EXECUTE dbo.sp_GetProducerDetailsByOrganisationId @organisationId";

            var sqlParameters = new List<SqlParameter>
            {
               new SqlParameter("@organisationId", SqlDbType.Int) { Value = organisationId }

            };

            response = await synapseContext.RunSqlAsync<ProducerDetailsModel>(Sql, sqlParameters.ToArray());

        }
        catch (Exception ex)
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