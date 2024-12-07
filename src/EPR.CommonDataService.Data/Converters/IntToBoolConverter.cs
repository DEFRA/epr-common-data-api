using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using System.Linq.Expressions;
using System.Runtime.CompilerServices;

namespace EPR.CommonDataService.Data.Converters;
public static class IntToBoolConverter
{
    private static int ConvertToProvider(bool? boolValue)
    {
        if (!boolValue.HasValue)
        {
            return 0;
        }

        return boolValue.Value ? 1 : 0;
    }

    private static bool? ConvertFromProvider(int intValue)
    {
        bool? result = intValue > 0;
        return result;
    }

    public static ValueConverter<bool?, int> Get()
    {
        Expression<Func<bool?, int>> toProvider = boolValue => ConvertToProvider(boolValue);
        Expression<Func<int, bool?>> fromProvider = intValue => ConvertFromProvider(intValue);

        return new ValueConverter<bool?, int>(toProvider, fromProvider);
    }
}