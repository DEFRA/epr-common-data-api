using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Data.Entities;

[ExcludeFromCodeCoverage]
public class ProducerDetailsModel
{
    public int NumberOfSubsidiaries { get; set; }
    public int NumberOfSubsidiariesBeingOnlineMarketPlace { get; set; }
    public string ProducerSize { get; set; }
    public bool IsOnlineMarketplace  { get; set; }
}