namespace EPR.CommonDataService.Data.Entities
{
    public class OrganisationRegistrationCSODetailsDto {
        public string CSOOrgName { get; set; }
        public string CSOReference { get; set; }
        public string SubmissionPeriod { get; set; }
        public string ReferenceNumber { get; set; }
        public int RelevantYear { get; set; }
        public string ProducerSize { get; set; }
        public string SubmittedDate { get; set; }
        public bool IsLateFeeApplicable { get; set; }
        public string MemberName { get; set; }
        public string LeaverCode { get; set; }
        public string LeaverDate { get; set; }
        public string JoinerDate { get; set; }
        public string OrganisationChangeReason { get; set; }
        public bool IsOnlineMarketPlace { get; set; }
        public int NumberOfSubsidiaries { get; set; }
        public int NumberOfSubsidiariesBeingOnlineMarketPlace { get; set; }
    }
}
