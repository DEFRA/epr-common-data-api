using EPR.CommonDataService.Api.Extensions;

namespace EPR.CommonDataService.Api.UnitTests.Extensions;

[TestClass]
public class GuidExtensionsTests
{
    [TestMethod]
    public void CheckInvalidGuid_InvalidGuid_ReturnsFalse()
    {
        // Arrange
        var userGuid = Guid.NewGuid();

        // Act
        var result = userGuid.IsInvalidGuid();
                        
        // Assert
        result.Should().Be(false);
    }

    [TestMethod]
    public void CheckInvalidGuid_EmptyGuid_ReturnsTrue()
    {
        var userGuid = Guid.Empty;

        // Act
        var result = userGuid.IsInvalidGuid();

        // Assert
        result.Should().Be(true);
    }
}