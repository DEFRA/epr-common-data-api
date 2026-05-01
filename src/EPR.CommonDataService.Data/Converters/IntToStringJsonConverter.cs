using System.Text.Json;
using System.Text.Json.Serialization;

namespace EPR.CommonDataService.Data.Converters;

public class IntToStringJsonConverter: JsonConverter<int?>
{
    public override int? Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        if (reader.TokenType == JsonTokenType.Null)
        {
            return null;
        }

        var value = reader.GetString();
        
        return string.IsNullOrWhiteSpace(value) ? null : int.Parse(value);
    }

    public override void Write(Utf8JsonWriter writer, int? value, JsonSerializerOptions options)
        => writer.WriteStringValue(value?.ToString());
}
