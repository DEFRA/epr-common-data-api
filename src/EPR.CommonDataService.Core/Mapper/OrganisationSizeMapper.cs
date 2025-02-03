namespace EPR.CommonDataService.Core.Mapper;


public static class OrganisationSizeMapper
{
    public static string Map(string? organisationSize)
    {
        if (string.IsNullOrWhiteSpace(organisationSize))
        {
            return "Unknown"; // Handle null, empty, or whitespace values
        }

        return organisationSize.ToLower() switch
        {
            "s" => "Small",
            "l" => "Large",
            _ => "Unknown" // Handle unexpected values
        };
    }
}
