using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Data.Entities;

[ExcludeFromCodeCoverage]
public class UpdatedProducersResponseModel
{
    public string OrganisationName { get; set; }
    public string TradingName { get; set; }
    public string OrganisationType { get; set; }
    public string CompaniesHouseNumber { get; set; }
    public string organisationId { get; set; }
    public string AddressLine1 { get; set; }
    public string AddressLine2 { get; set; }
    public string Town { get; set; }
    public string County { get; set; }
    public string Country { get; set; }
    public string Postcode { get; set; }
    public string pEPRID { get; set; }
    public string status { get; set; }
}