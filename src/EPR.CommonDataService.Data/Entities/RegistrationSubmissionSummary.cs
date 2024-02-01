namespace EPR.CommonDataService.Data.Entities;

public class RegistrationSubmissionSummary : SubmissionSummaryModel
{
    public string CompaniesHouseNumber { get; set; }
    public string SubBuildingName { get; set; }
    public string BuildingName { get; set; }
    public string BuildingNumber { get; set; }
    public string Street { get; set; }
    public string Locality { get; set; }
    public string DependentLocality { get; set; }
    public string Town { get; set; }
    public string County { get; set; }
    public string Country { get; set; }
    public string Postcode { get; set; }
    public Guid? CompanyDetailsFileId { get; set; }
    public string CompanyDetailsFileName { get; set; }
    public Guid? PartnershipFileId { get; set; }
    public string PartnershipFileName { get; set; }
    public Guid? BrandsFileId { get; set; }
    public string BrandsFileName { get; set; }
    public string? RegistrationDate { get; set; }
}