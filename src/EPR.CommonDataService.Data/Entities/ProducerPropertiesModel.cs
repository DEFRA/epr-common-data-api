using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Data.Entities;

[ExcludeFromCodeCoverage]
public class ProducerPropertiesModel
{
    public Guid OrganisationId { get; set; }
    public string ProducerSize { get; set; }
}