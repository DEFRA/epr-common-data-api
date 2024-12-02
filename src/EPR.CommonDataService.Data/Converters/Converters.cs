using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using System.Diagnostics.CodeAnalysis;
using System.Globalization;

namespace EPR.CommonDataService.Data.Converters;

[ExcludeFromCodeCoverage]
public static class StringToGuidConverter
{
    public static ValueConverter<Guid?, string> Get() => new (
        guidValue => guidValue == null ? null : guidValue.ToString(),
        stringValue => string.IsNullOrEmpty(stringValue) ? null : Guid.Parse(stringValue)
    );
}

[ExcludeFromCodeCoverage]
public static class StringToIntConverter
{
    public static ValueConverter<int?, string> Get() => new (
        intValue => intValue == null ? null : intValue.ToString(),
        stringValue => string.IsNullOrEmpty(stringValue) ? null : int.Parse(stringValue)
    );
}

[ExcludeFromCodeCoverage]
public static class StringToDateConverter
{
    public static ValueConverter<DateTime?, string> Get() => new(
        dateTimeValue => dateTimeValue == null ? null : dateTimeValue.ToString(),
        stringValue => string.IsNullOrEmpty(stringValue) ? null : DateTime.ParseExact(stringValue, "yyyy-MM-ddTHH:mm:ss.fffffffZ", CultureInfo.InvariantCulture )
    );
}

