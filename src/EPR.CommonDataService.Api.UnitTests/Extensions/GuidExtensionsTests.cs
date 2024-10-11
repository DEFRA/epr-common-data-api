using EPR.CommonDataService.Api.Extensions;

namespace EPR.CommonDataService.Api.UnitTests.Extensions;

[TestClass]
public class GuidExtensionsTests
{
    [TestMethod]
    public void CheckValidGuid_ValidGuid_ReturnsTrue()
    {
        // Arrange
        var userGuid = Guid.NewGuid();

        // Act
        var result = userGuid.IsInvalidValidGuid();
                        
        // Assert
        result.Should().Be(false);
    }

    [TestMethod]
    public void CheckValidGuid_EmptyGuid_ReturnsFalse()
    {
        var userGuid = Guid.Empty;

        // Act
        var result = userGuid.IsInvalidValidGuid();

        // Assert
        result.Should().Be(true);
    }
}