using System.ComponentModel.DataAnnotations;

namespace EPR.CommonDataService.Core.Models.Requests
{
    public class OrganisationRegistrationDetailRequest
    {
        [Required]
        public Guid SubmissionId { get; set; }
    }
}
