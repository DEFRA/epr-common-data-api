using System.Globalization;

namespace EPR.CommonDataService.Api.Features.PayCal;

public static class DateParserUtil
{
    public static DateTimeOffset? ParseCutoff(string? cutoffParam)
    {
        if (string.IsNullOrWhiteSpace(cutoffParam))
            return null;

        // Legacy client: yyyy-MM-dd
        if (DateOnly.TryParseExact(cutoffParam, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var dateOnly))
        {
            return new DateTimeOffset(dateOnly.ToDateTime(TimeOnly.MaxValue), TimeSpan.Zero);
        }

        // New client: ISO 8601 UTC DateTimeOffset
        if (DateTimeOffset.TryParseExact(cutoffParam, "yyyy-MM-dd'T'HH:mm:ss.FFFFFFF'Z'", CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var dateTimeOffset))
        {
            return dateTimeOffset;
        }

        throw new FormatException("cutoffDate must be in yyyy-MM-dd or ISO 8601 UTC DateTimeOffset format.");
    }

    public static bool IsValidCutoff(string? cutoffParam)
    {
        if (string.IsNullOrWhiteSpace(cutoffParam))
            return true;

        return DateOnly.TryParseExact(cutoffParam, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out _)
            || DateTimeOffset.TryParseExact(cutoffParam, "yyyy-MM-dd'T'HH:mm:ss.FFFFFFF'Z'", CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out _);
    }
}
