namespace EPR.CommonDataService.Data.Entities
{
    public class CSOMemberType
    {
        public string MemberId { get; set; }
        public string MemberType { get; set; }
        public bool IsOnlineMarketPlace { get; set; }
        public int NumberOfSubsidiaries { get; set; }
        public int NumberOfSubsidiariesOnlineMarketPlace { get; set; }
        public int RelevantYear { get; set; }
        public string SubmittedDate { get; set; }
        public bool IsLateFeeApplicable { get; set; }
        public string SubmissionPeriodDescription { get; set; }
    }
}
