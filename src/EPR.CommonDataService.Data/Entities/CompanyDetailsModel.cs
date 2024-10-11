using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Data.Entities;

[ExcludeFromCodeCoverage]
public class CompanyDetailsModel
{
    public Guid OrganisationId { get; set; }
    public bool IsOnlineMarketplace  { get; set; }
}