using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace EPR.CommonDataService.Data.Converters;

public static class StringToGuidConverter
{
    public static ValueConverter<Guid?, string> Get() => new (
        guidValue => guidValue == null ? null : guidValue.ToString(),
        stringValue => string.IsNullOrEmpty(stringValue) ? null : Guid.Parse(stringValue)
    );
}