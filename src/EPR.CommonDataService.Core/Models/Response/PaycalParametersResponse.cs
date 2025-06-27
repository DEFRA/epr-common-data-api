using System.Text.Json.Serialization;

namespace EPR.CommonDataService.Core.Models.Response;

public class PaycalParametersResponse
{
    public bool IsCso { get; set; }

    public int RelevantYear { get; set; }

    public string OrganisationSize { get; set; } = string.Empty;

    public string OrganisationType { get; set; } = string.Empty; 

    public bool IsLateFee { get; set; }

    public DateTime FirstSubmittedDate { get; set; }

    public DateTime? JoinerDate { get; set; }

    public DateTime? LeaverDate { get; set; }

    public string? LeaverCode { get; set; }

    public ProducerDetailsResponse? ProducerDetails { get; set; }

    public CsoMembershipDetailsResponse? CsoMembershipDetails { get; set; }
}

public class ProducerDetailsResponse
{
    public string ProducerType { get; set; } = string.Empty;

    public int NoOfSubsidiariesOnlineMarketPlace { get; set; }

    public int NoOfSubsidiaries { get; set; }

    public bool IsLateFeeApplicable { get; set; }

    public bool IsProducerOnlineMarketplace { get; set; }
}

public class CsoMembershipDetailsResponse
{
    public string MemberId { get; set; } = string.Empty;
    
    public string MemberType { get; set; } = string.Empty;

    public bool IsOnlineMarketPlace { get; set; }
    
    public bool IsLateFeeApplicable { get; set; }
    
    public int NumberOfSubsidiaries { get; set; }

    [JsonPropertyName("NumberOfSubsidiariesOnlineMarketPlace")]
    public int NoOfSubsidiariesOnlineMarketplace { get; set; }
    
    public int RelevantYear { get; set; }
    
    public DateTime SubmittedDate { get; set; }
    
    public string SubmissionPeriodDescription { get; set; } = string.Empty;
}