using System.ComponentModel.DataAnnotations.Schema;
using System.Diagnostics.CodeAnalysis;
using Microsoft.EntityFrameworkCore;

namespace EPR.CommonDataService.Data.Entities;

[ExcludeFromCodeCoverage]
[Table("SubmissionEvents",Schema = "apps")]
[Keyless]
public class SubmissionEvent
{
    public string? Created { get; set; }
    public bool RequiresBrandsFile { get; set; }
    public string? Comments { get; set; }
    public string? RegistrationSetId { get; set; }
    public bool IsResubmissionRequired { get; set; }
    public string SubmissionEventId { get; set; }
    public int DataCount { get; set; }
    public string? SubmissionId { get; set; }
    public string? Decision { get; set; }
    public string? RegulatorDecision { get; set; }
    public string? FileId { get; set; }
    public string? RejectionComments { get; set; }
    public bool IsValid { get; set; }
    public string? BlobName { get; set; }
    public string? AntivirusScanResult { get; set; }
    public string? Id { get; set; }
    public bool RequiresPartnershipsFile { get; set; }
    public string? Errors { get; set; }
    public string? FileName { get; set; }
    public string? ResubmissionRequired { get; set; }
    public string? FileType { get; set; }
    public string? UserId { get; set; }
    public string? ProducerId { get; set; }
    public string? SubmittedBy { get; set; }
    public string? RegulatorUserId { get; set; }
    public string? Type { get; set; }
    public string? BlobContainerName { get; set; }
    [Column("load_ts")]
    public DateTime LastSyncTime { get; set; }
}