using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Data.Entities
{
    /// <summary>
    /// Used to return all required information for an Organisation and Submission
    /// for the Submissions detail page
    /// </summary>
    [ExcludeFromCodeCoverage]
    public class OrganisationRegistrationDetailsDto
    {
        public Guid SubmissionId { get; set; }
        public Guid OrganisationId { get; set; }
        public string OrganisationName { get; set; }
        public string OrganisationReference { get; set; }
        public string ApplicationReferenceNumber { get; set; }
        public string RegistrationReferenceNumber { get; set; }

        public string SubmissionStatus { get; set; }
        public string StatusPendingDate { get; set; }
        public string SubmittedDateTime { get; set; }
        public bool IsLateSubmission { get; set; }
        public string SubmissionPeriod { get; set; }
        public int RelevantYear { get; set; }

        public string RegistrationDate { get; set; }
        public bool IsResubmission { get; set; }
        public string ResubmissionStatus { get; set; }
        public string ResubmissionDate { get; set; }

        public bool IsComplianceScheme { get; set; }
        public string OrganisationSize { get; set; }
        public string OrganisationType { get; set; }
        public int NationId { get; set; }
        public string NationCode { get; set; }

        public string RegulatorComment { get; set; }
        public string ProducerComment { get; set; }
        public string RegulatorDecisionDate { get; set; }
        public Guid? RegulatorUserId { get; set; }

        // organisation details
        public string CompaniesHouseNumber { get; set; }
        public string BuildingName { get; set; }
        public string SubBuildingName { get; set; }
        public string BuildingNumber { get; set; }
        public string Street { get; set; }
        public string Locality { get; set; }
        public string DependentLocality { get; set; }
        public string Town { get; set; }
        public string County { get; set; }
        public string Country { get; set; }
        public string Postcode { get; set; }

        // submittor details

        public Guid? SubmittedUserId { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string Email { get; set; }
        public string Telephone { get; set; }
        public string ServiceRole { get; set; }
        public int? ServiceRoleId { get; set; }

        // Paycal parameters
        public bool IsOnlineMarketPlace { get; set; }
        public int NumberOfSubsidiaries { get; set; }
        public int NumberOfOnlineSubsidiaries { get; set; }

        public Guid? CompanyDetailsFileId { get; set; }
        public string CompanyDetailsFileName { get; set; }
        public string CompanyDetailsBlobName { get; set; }
        public Guid? PartnershipFileId { get; set; }
        public string PartnershipFileName { get; set; }
        public string PartnershipBlobName { get; set; }
        public Guid? BrandsFileId { get; set; }
        public string BrandsFileName { get; set; }
        public string BrandsBlobName { get; set; }
        public string CSOJson { get; set; }
    }
}
