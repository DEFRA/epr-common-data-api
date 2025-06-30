namespace EPR.CommonDataService.Core.Models.Response;

public class OrganisationRegistrationSubmissionDetailsResponse
{
    public Guid SubmissionId { get; set; }
    
    public Guid OrganisationId { get; set; }

    public string OrganisationName { get; set; } = string.Empty;

    public string OrganisationReference { get; set; } = string.Empty;

    public string ApplicationReferenceNumber { get; set; } = string.Empty;

    public string? RegistrationReferenceNumber { get; set; } = string.Empty;

    public string SubmissionStatus { get; set; } = string.Empty;

    public DateTime? StatusPendingDate { get; set; }

    public string SubmittedDateTime { get; set; } = string.Empty;

    public bool IsResubmission { get; set; }

    public string ResubmissionStatus { get; set; } = string.Empty;

    public DateTime? RegistrationDate { get; set; }

    public DateTime? ResubmissionDate { get; set; }

    public string? ResubmissionFileId { get; internal set; }

    public string SubmissionPeriod { get; internal set; } = string.Empty;

    public int RelevantYear { get; set; }

    public bool IsComplianceScheme { get; set; }

    public string OrganisationSize { get; set; } = string.Empty;

    public string? OrganisationType { get; set; } = string.Empty;

    public int NationId { get; set; }

    public string NationCode { get; set; } = string.Empty;

    public string? RegulatorComment { get; set; } = string.Empty;

    public string? ProducerComment { get; set; } = string.Empty;

    public DateTime? RegulatorDecisionDate { get; internal set; }

    public DateTime? RegulatorResubmissionDecisionDate { get; set; }

    public Guid? RegulatorUserId { get; internal set; }
    
    public string CompaniesHouseNumber { get; set; } = string.Empty;
    
    public string? BuildingName { get; set; }
    
    public string? SubBuildingName { get; set; }
    
    public string? BuildingNumber { get; set; }
    
    public string Street { get; set; } = string.Empty;
    
    public string Locality { get; set; } = string.Empty;
    
    public string? DependentLocality { get; set; }
    
    public string Town { get; set; } = string.Empty;
    
    public string County { get; set; } = string.Empty;
    
    public string Country { get; set; } = string.Empty;
    
    public string Postcode { get; set; } = string.Empty;

    public Guid? SubmittedUserId { get; set; }
    
    public string FirstName { get; set; } = string.Empty;

    public string LastName { get; set; } = string.Empty;

    public string Email { get; set; } = string.Empty;

    public string Telephone { get; set; } = string.Empty;

    public string ServiceRole { get; set; } = string.Empty;

    public int? ServiceRoleId { get; set; }

    public Guid? CompanyDetailsFileId { get; set; }
    
    public string CompanyDetailsFileName { get; set; } = string.Empty;

    public string CompanyDetailsBlobName { get; set; } = string.Empty;

    public Guid? PartnershipFileId { get; set; }
    
    public string PartnershipFileName { get; set; } = string.Empty;

    public string PartnershipBlobName { get; set; } = string.Empty;

    public Guid? BrandsFileId { get; set; }
    
    public string BrandsFileName { get; set; } = string.Empty;

    public string BrandsBlobName { get; set; } = string.Empty;

    public string ComplianceSchemeId { get; set; } = string.Empty;
}