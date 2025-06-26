namespace EPR.CommonDataService.Core.Models.Response;

public class SubmissionStatusResponse
{
    public Guid SubmissionId { get; set; }

    public string RegistrationReferenceNumber { get; set; } = string.Empty;
    
    public string SubmissionStatus { get; set; } = string.Empty;

    public DateTime StatusPendingDate { get; set; }
    
    public DateTime SubmittedDateTime { get; set; }

    public bool IsResubmission { get; set; }

    public string ResubmissionStatus { get; set; } = string.Empty;
    
    public string ResubmissionDate { get; set; } = string.Empty;
}