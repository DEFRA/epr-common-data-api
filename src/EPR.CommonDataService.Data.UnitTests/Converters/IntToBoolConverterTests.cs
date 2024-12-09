using Microsoft.VisualStudio.TestTools.UnitTesting;
using EPR.CommonDataService.Data.Converters;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Globalization;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace EPR.CommonDataService.Data.Converters.Tests
{
    [TestClass()]
    public class IntToBoolConverterTests
    {
        private readonly ValueConverter<bool?, int> _converter = IntToBoolConverter.Get();

        [TestMethod]
        public void Given_NullBoolValue_When_ConvertedToInt_Should_Return0()
        {
            // Arrange
            bool? boolValue = null;

            // Act
            var result = _converter.ConvertToProvider(boolValue);

            // Assert
            result.Should().BeNull();
        }

        [TestMethod]
        public void Given_TrueBoolValue_When_ConvertedToInt_Should_Return1()
        {
            // Arrange
            bool? boolValue = true;

            // Act
            var result = _converter.ConvertToProvider(boolValue);

            // Assert
            result.Should().Be(1);
        }

        [TestMethod]
        public void Given_FalseBoolValue_When_ConvertedToInt_Should_Return0()
        {
            // Arrange
            bool? boolValue = false;

            // Act
            var result = _converter.ConvertToProvider(boolValue);

            // Assert
            result.Should().Be(0);
        }

        [TestMethod]
        public void Given_ZeroValue_When_ConvertedToBool_Should_ReturnFalse()
        {
            // Arrange
            int intValue = 0;

            // Act
            var result = _converter.ConvertFromProvider(intValue);

            // Assert
            result.Should().Be(false);
        }

        [TestMethod]
        public void Given_PositiveValue_When_ConvertedToBool_Should_ReturnTrue()
        {
            // Arrange
            int intValue = 1;

            // Act
            var result = _converter.ConvertFromProvider(intValue);

            // Assert
            result.Should().Be(true);
        }

        [TestMethod]
        public void Given_NegativeValue_When_ConvertedToBool_Should_ReturnFalse()
        {
            // Arrange
            int intValue = -1;

            // Act
            var result = _converter.ConvertFromProvider(intValue);

            // Assert
            result.Should().Be(false);
        }
    }
}