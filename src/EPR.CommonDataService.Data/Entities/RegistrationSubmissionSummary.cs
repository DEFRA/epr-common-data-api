using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Data.Entities;

[ExcludeFromCodeCoverage]
public class RegistrationSubmissionSummary
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
    public string CompanyDetailsBlobName { get; set; }
    public Guid? PartnershipFileId { get; set; }
    public string PartnershipFileName { get; set; }
    public string PartnershipBlobName { get; set; }
    public Guid? BrandsFileId { get; set; }
    public string BrandsFileName { get; set; }
    public string BrandsBlobName { get; set; }
    public string RegistrationDate { get; set; }
    public Guid? SubmissionId { get; set; }
    public Guid? OrganisationId { get; set; }
    public Guid? ComplianceSchemeId { get; set; }
    public string OrganisationName { get; set; }
    
    public string OrganisationReference { get; set; }
    
    public string OrganisationType { get; set; }
    public string ProducerType { get; set; }
    public Guid? UserId { get; set; }
    public string FirstName { get; set; }
    public string LastName { get; set; }
    public string Email { get; set; }
    public string Telephone { get; set; }
    public string ServiceRole { get; set; }
    public string SubmissionPeriod { get; set; }
    public string Decision { get; set; }
    public string Comments { get; set; }
    public bool IsResubmission { get; set; }
    public string PreviousRejectionComments { get; set; }
    public int NationId { get; set; }
}