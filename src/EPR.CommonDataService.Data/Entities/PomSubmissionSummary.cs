namespace EPR.CommonDataService.Data.Entities;

public class PomSubmissionSummary: SubmissionSummaryModel
{
    public Guid? FileId { get; set; }
    public bool IsResubmissionRequired { get; set; }
    public string? SubmittedDate { get; set; }
}