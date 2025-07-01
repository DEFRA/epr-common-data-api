using Newtonsoft.Json;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;

namespace EPR.CommonDataService.Core.Models.Response;

public class PaycalParametersResponse
{
    public bool IsCso { get; set; }

    public string SubmissionPeriod { get; set; } = string.Empty;

    public int ReferenceNumber { get; set; }

    public string ExternalId { get; set; } = string.Empty;

    public string OrganisationName { get; set; } = string.Empty;

    public int RelevantYear { get; set; }

    public DateTime SubmittedDate { get; set; }

    public DateTime EarliestSubmissionDate { get; set; }

    public string OrganisationSize { get; set; } = string.Empty;

    public string? LeaverCode { get; set; }

    public DateTime? LeaverDate { get; set; }

    public DateTime? JoinerDate { get; set; }

    public string OrganisationChangeReason { get; set; } = string.Empty; 

    public bool IsOnlineMarketPlace { get; set; }

    public int NoOfSubsidiaries { get; set; }

    public int NoOfSubsidiariesBeingOnlineMarketPlace { get; set; }
    
    public Guid FileName { get; set; }

    public Guid FileId { get; set; }

    public bool IsLateFee { get; set; }    
}

public class ProducerPaycalParametersResponse : PaycalParametersResponse
{    
}

public class CsoPaycalParametersResponse : PaycalParametersResponse
{
    public string CsoReference { get; set; } = string.Empty;

    public Guid CsoExternalId { get; set; }

    public Guid ComplianceSchemeId { get; set; }

    public bool IsOriginal { get; set; }

    public bool IsNewJoiner { get; set; }
}