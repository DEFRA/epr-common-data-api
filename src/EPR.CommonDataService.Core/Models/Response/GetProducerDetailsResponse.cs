using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Core.Models.Response;

[ExcludeFromCodeCoverage]
public class GetProducerDetailsResponse
{
    public int NumberOfSubsidiaries { get; set; }
    public int NumberOfSubsidiariesBeingOnlineMarketPlace { get; set; }
    public string ProducerSize { get; set; } = string.Empty;
    public bool IsOnlineMarketplace  { get; set; }
    public string NationFromUploadedFile { get; set; } = string.Empty;
}
