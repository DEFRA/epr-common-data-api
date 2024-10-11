namespace EPR.CommonDataService.Core.Models.Response;

public class GetOnlineMarketplaceFlagResponse
{
    public Guid OrganisationId { get; set; }

    public bool IsOnlineMarketPlace { get; set; }
}