using System.Data;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;

namespace EPR.CommonDataService.Core.Services;

public interface ICompanyDetailsService
{
    Task<GetOnlineMarketplaceFlagResponse?> GetOnlineMarketplaceFlag(Guid organisationId);
}

public class CompanyDetailsService(
    SynapseContext synapseContext) 
    : ICompanyDetailsService
{
    public async Task<GetOnlineMarketplaceFlagResponse?> GetOnlineMarketplaceFlag(Guid organisationId)
    {
        IList<CompanyDetailsModel> response;
        try
        {
            const string Sql = "EXECUTE apps.sp_GetOnlineMarketplaceFlag @OrganisationId";

            var sqlParameters = new List<SqlParameter>
            {
                new ("@OrganisationId", SqlDbType.UniqueIdentifier, 255) {
                    Value = organisationId
                }
            };

            response = await synapseContext.RunSqlAsync<CompanyDetailsModel>(Sql, sqlParameters);
        }
        catch
        {
            return null;
        }

        var firstItem = response.FirstOrDefault();

        return firstItem is null ? null :

        new GetOnlineMarketplaceFlagResponse
        {
            IsOnlineMarketPlace = firstItem.IsOnlineMarketplace,
            OrganisationId = firstItem.OrganisationId
        };
    }
}