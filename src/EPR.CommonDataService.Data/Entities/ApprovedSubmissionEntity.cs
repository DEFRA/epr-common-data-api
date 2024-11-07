namespace EPR.CommonDataService.Data.Entities
{
    public class ApprovedSubmissionEntity
    {
        public string SubmissionPeriod { get; set; }
        public string PackagingMaterial { get; set; }
        public double PackagingMaterialWeight { get; set; }
        public Guid OrganisationId { get; set; }
    }
}
