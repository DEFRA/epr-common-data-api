namespace EPR.CommonDataService.Api.Extensions;

public static class GuidExtensions
{
    public static bool IsInvalidGuid(this string guidValue, out Guid validGuid)
    {
        return !Guid.TryParse(guidValue, out validGuid) || validGuid == Guid.Empty;
    }
}