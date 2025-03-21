﻿using EPR.CommonDataService.Core.Mapper;

namespace EPR.CommonDataService.Core.UnitTests.Mapper
{
    [TestClass]
    public class OrganisationSizeMapperTests
    {
        [TestMethod]
        [DataRow("s", "Small")]  // Lowercase valid input
        [DataRow("l", "Large")]  // Lowercase valid input
        [DataRow("S", "Small")]  // Uppercase valid input
        [DataRow("L", "Large")]  // Uppercase valid input
        [DataRow(null, "Unknown")]  // Null input
        [DataRow("", "Unknown")]  // Empty input
        [DataRow(" ", "Unknown")]  // Whitespace input
        [DataRow("x", "Unknown")]  // Invalid input
        [DataRow("small", "Unknown")]  // Unexpected valid word
        public void Map_ReturnsExpectedResult(string? input, string expected)
        {
            // Act
            var result = OrganisationSizeMapper.Map(input);

            // Assert
            Assert.AreEqual(expected, result);
        }
    }
}
