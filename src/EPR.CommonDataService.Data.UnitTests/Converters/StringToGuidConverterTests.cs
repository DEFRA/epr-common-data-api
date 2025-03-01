using EPR.CommonDataService.Data.Converters;
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Data.UnitTests.Converters;

[ExcludeFromCodeCoverage]
[TestClass]
public class StringToGuidConverterTests
{
    [TestMethod]
    public void Given_NullGuidValue_When_ConvertedToString_Should_ReturnNull()
    {
        // Arrange
        Guid? guidValue = null;
        var converter = StringToGuidConverter.Get();

        // Act
        var result = converter.ConvertToProvider(guidValue);

        // Assert
        result.Should().BeNull();
    }

    [TestMethod]
    public void Given_ValidGuidValue_When_ConvertedToString_Should_ReturnCorrectString()
    {
        // Arrange
        var guidValue = Guid.NewGuid();
        var converter = StringToGuidConverter.Get();

        // Act
        var result = converter.ConvertToProvider(guidValue);

        // Assert
        result.Should().Be(guidValue.ToString());
    }

    [TestMethod]
    public void Given_EmptyStringValue_When_ConvertedToGuid_Should_ReturnNull()
    {
        // Arrange
        var converter = StringToGuidConverter.Get();

        // Act
        var result = converter.ConvertFromProvider(string.Empty);

        // Assert
        result.Should().BeNull();
    }

    [TestMethod]
    public void Given_NullStringValue_When_ConvertedToGuid_Should_ReturnNull()
    {
        // Arrange null test
        string stringValue = null!;
        var converter = StringToGuidConverter.Get();

        // Act
        var result = converter.ConvertFromProvider(stringValue);

        // Assert
        result.Should().BeNull();
    }

    [TestMethod]
    public void Given_ValidStringValue_When_ConvertedToGuid_Should_ReturnCorrectGuid()
    {
        // Arrange
        var guidValue = Guid.NewGuid();
        var stringValue = guidValue.ToString();
        var converter = StringToGuidConverter.Get();

        // Act
        var result = converter.ConvertFromProvider(stringValue);

        // Assert
        result.Should().Be(guidValue);
    }

    [TestMethod]
    public void Given_InvalidStringValue_When_ConvertedToGuid_Should_ThrowFormatException()
    {
        // Arrange
        const string InvalidGuidString = "invalid-guid-string";
        var converter = StringToGuidConverter.Get();

        // Act
        var act = () => converter.ConvertFromProvider(InvalidGuidString);

        act.Should().Throw<FormatException>();
        // Assert - should be handled by expected exception attribute
    }
}
