using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace EPR.CommonDataService.Data.Converters;

public static class IntToBoolConverter
{
    public static ValueConverter<bool?, int> Get() => new(
        boolValue => boolValue.HasValue && boolValue.Value ? 1 : 0,
        intValue => intValue > 0
    );
}