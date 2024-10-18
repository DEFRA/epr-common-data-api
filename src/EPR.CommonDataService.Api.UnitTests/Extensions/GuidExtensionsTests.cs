using EPR.CommonDataService.Api.Extensions;

namespace EPR.CommonDataService.Api.UnitTests.Extensions;

[TestClass]
public class GuidExtensionsTests
{
    [TestMethod]
    public void CheckInvalidGuid_InvalidGuid_ReturnsFalse()
    {
        // Arrange
        var userGuid = Guid.NewGuid().ToString();

        // Act
        var result = userGuid.IsInvalidGuid(out _);
                        
        // Assert
        result.Should().Be(false);
    }

    [TestMethod]
    public void CheckInvalidGuid_EmptyGuid_ReturnsTrue()
    {
        var userGuid = Guid.Empty.ToString();

        // Act
        var result = userGuid.IsInvalidGuid(out var validGuid);

        // Assert
        result.Should().Be(true);
    }
}