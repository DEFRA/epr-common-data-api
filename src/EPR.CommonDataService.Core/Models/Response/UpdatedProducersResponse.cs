using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Core.Models.Response
{
    [ExcludeFromCodeCoverage]
    public class UpdatedProducersResponse
    {
        public string? OrganisationName { get; set; }
        public string? TradingName { get; set; }
        public string? OrganisationType { get; set; }
        public string? CompaniesHouseNumber { get; set; }
        public string? OrganisationId { get; set; }
        public string? AddressLine1 { get; set; }
        public string? AddressLine2 { get; set; }
        public string? Town { get; set; }
        public string? County { get; set; }
        public string? Country { get; set; }
        public string? Postcode { get; set; }
        public string? PEPRID { get; set; }
    }
}
