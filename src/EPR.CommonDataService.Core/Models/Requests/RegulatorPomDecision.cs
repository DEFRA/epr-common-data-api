using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Core.Models.Requests;

[ExcludeFromCodeCoverage]
public class RegulatorPomDecision
{
    public Guid FileId { get; set; }
    public string Decision { get; set; } = string.Empty;
    public string? Comments { get; set; }
    public bool IsResubmissionRequired { get; set;  }
}