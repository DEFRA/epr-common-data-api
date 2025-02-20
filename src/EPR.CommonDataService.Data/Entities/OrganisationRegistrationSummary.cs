using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Data.Entities
{
    /// <summary>
    /// Used to return information the Organisation Registration Submissions List
    /// </summary>
    [ExcludeFromCodeCoverage]
    public class OrganisationRegistrationSummaryDto
    {
        public Guid SubmissionId { get; set; }
        public Guid OrganisationId { get; set; }
        public string OrganisationType { get; set; }
        public string OrganisationName { get; set; }
        public string OrganisationReference { get; set; }
        public string SubmissionStatus { get; set; }
        public string StatusPendingDate { get; set; }
        public string ApplicationReferenceNumber { get; set; }
        public string RegistrationReferenceNumber { get; set; }
        public int RelevantYear { get; set; }
        public string SubmittedDateTime { get; set; }
        public int NationId { get; set; }
        public bool IsResubmission { get; set; }
    }

    [ExcludeFromCodeCoverage]
    public class OrganisationRegistrationSummaryDataRow : OrganisationRegistrationSummaryDto
    {
        public int TotalItems { get; set; }
    }
}
