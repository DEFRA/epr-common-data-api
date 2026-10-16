using System.Globalization;

namespace EPR.CommonDataService.Api.Features.PayCal.Fss.v1.BillingOrganisations.Get;

public static class FinancialYear
{
    public static bool IsValid(string? value) =>
        value is { Length: 7 } &&
        value[4] == '-' &&
        int.TryParse(value[..4], NumberStyles.None, CultureInfo.InvariantCulture, out var start) &&
        int.TryParse(value[5..], NumberStyles.None, CultureInfo.InvariantCulture, out var end) &&
        start > 2000 &&
        end == (start + 1) % 100;

    public static int ToRelativeYear(string value) =>
        int.Parse(value[..4], CultureInfo.InvariantCulture);

    public static string FromRelativeYear(int relativeYear) =>
        $"{relativeYear}-{(relativeYear + 1) % 100:D2}";
}
