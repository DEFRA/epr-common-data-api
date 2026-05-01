using System.Diagnostics.CodeAnalysis;
using System.Text.Json.Serialization;
using EPR.CommonDataService.Data.Converters;

namespace EPR.CommonDataService.Data.Entities;

[ExcludeFromCodeCoverage]
public class SubmissionSummaryModel
{
    public Guid? SubmissionId { get; set; }
    public Guid? OrganisationId { get; set; }
    public Guid? ComplianceSchemeId { get; set; }
    public string OrganisationName { get; set; }
    
    // The value returned from the database is an int, but we
    // must return a string via webapi
    [JsonConverter(typeof(IntToStringJsonConverter))]
    public int? OrganisationReference { get; set; }
    
    public string OrganisationType { get; set; }
    public string ProducerType { get; set; }
    public Guid? UserId { get; set; }
    public string FirstName { get; set; }
    public string LastName { get; set; }
    public string Email { get; set; }
    public string Telephone { get; set; }
    public string ServiceRole { get; set; }
    public string SubmissionPeriod { get; set; }
    public string Decision { get; set; }
    public string Comments { get; set; }
    public bool IsResubmission { get; set; }
    public string PreviousRejectionComments { get; set; }
    public Byte NationId { get; set; }
}