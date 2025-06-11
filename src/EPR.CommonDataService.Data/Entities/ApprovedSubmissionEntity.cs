namespace EPR.CommonDataService.Data.Entities
{
    public class ApprovedSubmissionEntity
    {
        public string SubmissionPeriod { get; set; }
        public string PackagingMaterial { get; set; }
        public int PackagingMaterialWeight { get; set; }
        public Guid OrganisationId { get; set; }
        public Guid SubmitterId { get; set; }
        public string SubmitterType { get; set; }
    }
}
