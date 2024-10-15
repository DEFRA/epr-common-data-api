namespace EPR.CommonDataService.Api.Extensions;

public static class GuidExtensions
{
    public static bool IsInvalidGuid(this Guid guidValue)
    {
        return (!Guid.TryParse(guidValue.ToString(), out var validUserId)) || validUserId == Guid.Empty;
    }
}