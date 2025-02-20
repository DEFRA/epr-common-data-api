using EPR.CommonDataService.Data.Converters;
using System.Globalization;

namespace EPR.CommonDataService.Data.UnitTests.Converters;

[TestClass()]
public class StringToDateConverterTests
{
    [TestMethod]
    public void Given_NullDateTimeValue_When_ConvertedToString_Should_ReturnNull()
    {
        // Arrange
        DateTime? dateValue = null;
        var converter = StringToDateConverter.Get();

        // Act
        var result = converter.ConvertToProvider(dateValue);

        // Assert
        result.Should().BeNull();
    }

    [TestMethod]
    public void Given_ValidDateTimeValue_When_ConvertedToString_Should_ReturnCorrectString()
    {
        // Arrange
        var DateTimeValue = DateTime.Now;
        var stringValue = DateTimeValue.ToString("yyyy-MM-ddTHH:mm:ss.fffffffZ", CultureInfo.InvariantCulture);

        var converter = StringToDateConverter.Get();

        // Act
        var result = converter.ConvertToProvider(DateTimeValue);
        result.Should().Be(stringValue);
    }

    [TestMethod]
    public void Given_EmptyStringValue_When_ConvertedToDateTime_Should_ReturnNull()
    {
        // Arrange
        var converter = StringToDateConverter.Get();

        // Act
        var result = converter.ConvertFromProvider(string.Empty);

        // Assert
        result.Should().BeNull();
    }

    [TestMethod]
    public void Given_NullStringValue_When_ConvertedToDateTime_Should_ReturnNull()
    {
        // Arrange null test
        string stringValue = null!;
        var converter = StringToDateConverter.Get();

        // Act
        var result = converter.ConvertFromProvider(stringValue);

        // Assert
        result.Should().BeNull();
    }

    [Ignore("TODO::Check the reason for failure")]
    [TestMethod]
    public void Given_ValidStringValue_When_ConvertedToDateTime_Should_ReturnCorrectDateTime()
    {
        // Arrange
        var DateTimeValue = DateTime.Now;
        var stringValue = DateTimeValue.ToString("yyyy-MM-ddTHH:mm:ss.fffffffZ", CultureInfo.InvariantCulture);

        var converter = StringToDateConverter.Get();

        // Act
        var result = converter.ConvertFromProvider(stringValue);

        // Assert
        result.Should().Be(DateTimeValue);
    }

    [TestMethod]
    public void Given_InvalidStringValue_When_ConvertedToDateTime_Should_ThrowFormatException()
    {
        // Arrange
        const string InvalidDateTimeString = "invalid-DateTime-string";
        var converter = StringToDateConverter.Get();

        // Act
        var act = () => converter.ConvertFromProvider(InvalidDateTimeString);

        act.Should().Throw<FormatException>();
        // Assert - should be handled by expected exception attribute
    }
}