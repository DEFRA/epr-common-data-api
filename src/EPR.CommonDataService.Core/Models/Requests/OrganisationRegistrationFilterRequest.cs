using System.ComponentModel.DataAnnotations;
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Core.Models.Requests
{
    [ExcludeFromCodeCoverage]
    public class OrganisationRegistrationFilterRequest : IPaginatedRequest
    {
        public string? OrganisationNameCommaSeparated { get; set; }
        public string? OrganisationIDCommaSeparated { get; set; }
        public string? RelevantYearCommaSeparated { get; set; }
        public string? SubmissionStatusCommaSeparated { get; set; }
        public string? ResubmissionStatusCommaSeparated { get; set; }
        public string? OrganisationTypesCommaSeparated { get; set; }

        public string? ApplicationReferenceNumbers { get; set; }

        [Required]
        public int PageNumber { get; set; }
        [Required]
        public int PageSize { get; set; }
    }
}
