namespace EPR.CommonDataService.Data.Entities
{
    [Microsoft.EntityFrameworkCore.Keyless]
    public class ApprovedSubmissionWithObligationsEntity
    {
        public string SubmissionPeriod { get; set; }
        public string PackagingMaterial { get; set; }
        public int PackagingMaterialWeight { get; set; }
        public Guid OrganisationId { get; set; }
        public Guid SubmitterId { get; set; }
        public string SubmitterType { get; set; }
        public short? NumberOfDaysObligated { get; set; }
        public long PackagingMaterialWeightKg { get; set; }
        public string ObligationStatus { get; set; }
        public string LeaverCode { get; set; }
        public DateTime? JoinerDate { get; set; }
        public DateTime? LeaverDate { get; set; }
    }
}
