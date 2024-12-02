using Microsoft.VisualStudio.TestTools.UnitTesting;
using EPR.CommonDataService.Data.Converters;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Globalization;

namespace EPR.CommonDataService.Data.UnitTests.Converters;

[TestClass()]
public class StringToIntConverterTests
{
    [TestMethod]
    public void Given_NullIntegerValue_When_ConvertedToString_Should_ReturnNull()
    {
        // Arrange
        int? dateValue = null;
        var converter = StringToIntConverter.Get();

        // Act
        var result = converter.ConvertToProvider(dateValue);

        // Assert
        result.Should().BeNull();
    }

    [TestMethod]
    public void Given_ValidIntegerValue_When_ConvertedToString_Should_ReturnCorrectString()
    {
        // Arrange
        var IntegerValue = 101;
        var stringValue = IntegerValue.ToString(CultureInfo.InvariantCulture);
        var converter = StringToIntConverter.Get();

        // Act
        var result = converter.ConvertToProvider(IntegerValue);

        // Assert
        result.Should().Be(stringValue);
    }

    [TestMethod]
    public void Given_EmptyStringValue_When_ConvertedToDateTime_Should_ReturnNull()
    {
        // Arrange
        var converter = StringToIntConverter.Get();

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
        var converter = StringToIntConverter.Get();

        // Act
        var result = converter.ConvertFromProvider(stringValue);

        // Assert
        result.Should().BeNull();
    }

    [TestMethod]
    public void Given_ValidStringValue_When_ConvertedToDateTime_Should_ReturnCorrectDateTime()
    {
        // Arrange
        var IntegerValue = 101;
        var stringValue = IntegerValue.ToString(CultureInfo.InvariantCulture);

        var converter = StringToIntConverter.Get();

        // Act
        var result = converter.ConvertFromProvider(stringValue);

        // Assert
        result.Should().Be(IntegerValue);
    }

    [TestMethod]
    public void Given_InvalidStringValue_When_ConvertedToDateTime_Should_ThrowFormatException()
    {
        // Arrange
        const string InvalidDateTimeString = "invalid-DateTime-string";
        var converter = StringToIntConverter.Get();

        // Act
        var act = () => converter.ConvertFromProvider(InvalidDateTimeString);

        act.Should().Throw<FormatException>();
        // Assert - should be handled by expected exception attribute
    }
}