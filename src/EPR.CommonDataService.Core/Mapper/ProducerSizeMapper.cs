namespace EPR.CommonDataService.Core.Mapper;

public partial class ProducerDetailsService
{
    public static class ProducerSizeMapper
    {
        public static string Map(string? producerSize)
        {
            if (string.IsNullOrWhiteSpace(producerSize))
            {
                return "Unknown"; // Handle null, empty, or whitespace values
            }

            return producerSize.ToLower() switch
            {
                "s" => "Small",
                "l" => "Large",
                _ => "Unknown" // Handle unexpected values
            };
        }
    }


}