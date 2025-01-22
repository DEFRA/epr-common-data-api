namespace EPR.CommonDataService.Data.Entities;

public class PomSubmissionSummary: SubmissionSummaryModel
{
    public Guid? FileId { get; set; }
    public bool IsResubmissionRequired { get; set; }
    public string SubmittedDate { get; set; }
    public int SubmissionYear { get; set; }
    public string SubmissionCode { get; set; }
    public string ActualSubmissionPeriod { get; set; }
    public string PomFileName { get; set; }
    public string PomBlobName { get; set; }
}