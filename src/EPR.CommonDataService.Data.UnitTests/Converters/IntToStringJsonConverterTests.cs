using EPR.CommonDataService.Data.Converters;
using System.Text.Json;

namespace EPR.CommonDataService.Data.UnitTests.Converters;

[TestClass]
public class IntToStringJsonConverterTests
{
    private IntToStringJsonConverter _converter = null!;
    private JsonSerializerOptions _options = null!;

    [TestInitialize]
    public void Setup()
    {
        _converter = new IntToStringJsonConverter();
        _options = new JsonSerializerOptions();
    }

    #region Write Tests

    [TestMethod]
    public void Given_NullIntValue_When_WriteIsCalled_Should_WriteNullStringValue()
    {
        // Arrange
        int? intValue = null;
        using var stream = new MemoryStream();
        using var writer = new Utf8JsonWriter(stream);

        // Act
        _converter.Write(writer, intValue, _options);
        writer.Flush();

        // Assert
        var result = System.Text.Encoding.UTF8.GetString(stream.ToArray());
        result.Should().Be("null");
    }

    [TestMethod]
    public void Given_ValidIntValue_When_WriteIsCalled_Should_WriteIntAsString()
    {
        // Arrange
        int? intValue = 12345;
        using var stream = new MemoryStream();
        using var writer = new Utf8JsonWriter(stream);

        // Act
        _converter.Write(writer, intValue, _options);
        writer.Flush();

        // Assert
        var result = System.Text.Encoding.UTF8.GetString(stream.ToArray());
        result.Should().Be("\"12345\"");
    }

    [TestMethod]
    public void Given_ZeroValue_When_WriteIsCalled_Should_WriteZeroAsString()
    {
        // Arrange
        int? intValue = 0;
        using var stream = new MemoryStream();
        using var writer = new Utf8JsonWriter(stream);

        // Act
        _converter.Write(writer, intValue, _options);
        writer.Flush();

        // Assert
        var result = System.Text.Encoding.UTF8.GetString(stream.ToArray());
        result.Should().Be("\"0\"");
    }

    [TestMethod]
    public void Given_NegativeIntValue_When_WriteIsCalled_Should_WriteNegativeIntAsString()
    {
        // Arrange
        int? intValue = -9999;
        using var stream = new MemoryStream();
        using var writer = new Utf8JsonWriter(stream);

        // Act
        _converter.Write(writer, intValue, _options);
        writer.Flush();

        // Assert
        var result = System.Text.Encoding.UTF8.GetString(stream.ToArray());
        result.Should().Be("\"-9999\"");
    }

    #endregion

    #region Read Tests

    [TestMethod]
    public void Given_NullJsonValue_When_ReadIsCalled_Should_ReturnNull()
    {
        // Arrange
        var json = "null";
        var reader = new Utf8JsonReader(System.Text.Encoding.UTF8.GetBytes(json));
        reader.Read(); // Move to the null token

        // Act
        var result = _converter.Read(ref reader, typeof(int?), _options);

        // Assert
        result.Should().BeNull();
    }

    [TestMethod]
    public void Given_ValidStringNumber_When_ReadIsCalled_Should_ReturnParsedInt()
    {
        // Arrange
        var json = "\"54321\"";
        var reader = new Utf8JsonReader(System.Text.Encoding.UTF8.GetBytes(json));
        reader.Read(); // Move to the string token

        // Act
        var result = _converter.Read(ref reader, typeof(int?), _options);

        // Assert
        result.Should().Be(54321);
    }

    [TestMethod]
    public void Given_ZeroAsString_When_ReadIsCalled_Should_ReturnZero()
    {
        // Arrange
        var json = "\"0\"";
        var reader = new Utf8JsonReader(System.Text.Encoding.UTF8.GetBytes(json));
        reader.Read(); // Move to the string token

        // Act
        var result = _converter.Read(ref reader, typeof(int?), _options);

        // Assert
        result.Should().Be(0);
    }

    [TestMethod]
    public void Given_NegativeNumberAsString_When_ReadIsCalled_Should_ReturnNegativeInt()
    {
        // Arrange
        var json = "\"-7777\"";
        var reader = new Utf8JsonReader(System.Text.Encoding.UTF8.GetBytes(json));
        reader.Read(); // Move to the string token

        // Act
        var result = _converter.Read(ref reader, typeof(int?), _options);

        // Assert
        result.Should().Be(-7777);
    }

    [TestMethod]
    public void Given_InvalidStringValue_When_ReadIsCalled_Should_ThrowFormatException()
    {
        // Arrange
        var json = "\"invalid-number\"";

        // Act & Assert
        var act = () =>
        {
            var reader = new Utf8JsonReader(System.Text.Encoding.UTF8.GetBytes(json));
            reader.Read(); // Move to the string token
            _converter.Read(ref reader, typeof(int?), _options);
        };

        act.Should().Throw<FormatException>();
    }

    [TestMethod]
    public void Given_EmptyString_When_ReadIsCalled_Should_ReturnNull()
    {
        // Arrange
        var json = "\"\"";
        var reader = new Utf8JsonReader(System.Text.Encoding.UTF8.GetBytes(json));
        reader.Read(); // Move to the string token

        // Act
        var result = _converter.Read(ref reader, typeof(int?), _options);

        // Assert
        result.Should().BeNull();
    }

    #endregion

    #region Integration Tests

    [TestMethod]
    public void Given_CompleteJsonObject_When_DeserializedWithConverter_Should_ConvertStringToInt()
    {
        // Arrange
        var json = """{"Value":"12345"}""";
        var options = new JsonSerializerOptions();
        options.Converters.Add(_converter);

        // Act
        var result = JsonSerializer.Deserialize<TestModel>(json, options);

        // Assert
        result.Should().NotBeNull();
        result?.Value.Should().Be(12345);
    }

    [TestMethod]
    public void Given_CompleteJsonObject_When_SerializedWithConverter_Should_ConvertIntToString()
    {
        // Arrange
        var model = new TestModel { Value = 98765 };
        var options = new JsonSerializerOptions();
        options.Converters.Add(_converter);

        // Act
        var json = JsonSerializer.Serialize(model, options);

        // Assert
        json.Should().Contain("\"98765\"");
    }

    [TestMethod]
    public void Given_JsonObjectWithNullValue_When_DeserializedWithConverter_Should_ReturnNull()
    {
        // Arrange
        var json = """{"value":null}""";
        var options = new JsonSerializerOptions();
        options.Converters.Add(_converter);

        // Act
        var result = JsonSerializer.Deserialize<TestModel>(json, options);

        // Assert
        result.Should().NotBeNull();
        result?.Value.Should().BeNull();
    }

    #endregion

    private class TestModel
    {
        [System.Text.Json.Serialization.JsonConverter(typeof(IntToStringJsonConverter))]
        public int? Value { get; set; }
    }
}
