using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace EPR.CommonDataService.Data.Converters;

public static class StringToGuidConverter
{
    public static ValueConverter<Guid?, string> Get() => new (
        guidValue => guidValue == null ? null : guidValue.ToString(),
        stringValue => string.IsNullOrEmpty(stringValue) ? null : Guid.Parse(stringValue)
    );
}

public static class IntToBoolConverter
{
    public static ValueConverter<bool?, int> Get() => new(
        boolValue => boolValue.HasValue && boolValue.Value ? 1 : 0,
        intValue => intValue > 0
    );
}