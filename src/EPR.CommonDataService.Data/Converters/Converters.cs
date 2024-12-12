using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using System.Globalization;

namespace EPR.CommonDataService.Data.Converters;

public static class StringToGuidConverter
{
    public static ValueConverter<Guid?, string> Get() => new (
        guidValue => guidValue == null ? null : guidValue.ToString(),
        stringValue => string.IsNullOrEmpty(stringValue) ? null : Guid.Parse(stringValue)
    );
}

public static class StringToIntConverter
{
    public static ValueConverter<int?, string> Get() => new (
        intValue => intValue == null ? null : intValue.ToString(),
        stringValue => string.IsNullOrEmpty(stringValue) ? null : int.Parse(stringValue)
    );
}

public static class StringToDateConverter
{
    public static ValueConverter<DateTime?, string> Get() => new(
        dateTimeValue => dateTimeValue == null ? null : dateTimeValue.Value.ToString("yyyy-MM-ddTHH:mm:ss.fffffffZ", CultureInfo.InvariantCulture),
        stringValue => string.IsNullOrEmpty(stringValue) ? null : DateTime.ParseExact(stringValue, "yyyy-MM-ddTHH:mm:ss.fffffffZ", CultureInfo.InvariantCulture )
    );
}

