using EPR.CommonDataService.Api.HealthChecks;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace EPR.CommonDataService.Api.UnitTests.HealthChecks
{
    [TestClass]
    public class HealthCheckOptionsBuilderTests
    {
        [TestMethod]
        public void Build_ShouldReturnHealthCheckOptions()
        {
            // Act
            var result = HealthCheckOptionBuilder.Build();

            // Assert
            result.Should().NotBeNull();
        }

        [TestMethod]
        public void Build_ShouldSetAllowCachingResponsesToFalse()
        {
            // Act
            var result = HealthCheckOptionBuilder.Build();

            // Assert
            result.AllowCachingResponses.Should().BeFalse();
        }

        [TestMethod]
        public void Build_ShouldSetHealthyStatusCodeTo200()
        {
            // Act
            var result = HealthCheckOptionBuilder.Build();

            // Assert
            result.ResultStatusCodes[HealthStatus.Healthy].Should().Be(StatusCodes.Status200OK);
        }

        [TestMethod]
        public void Build_ShouldInitializeResultStatusCodes()
        {
            // Act
            var result = HealthCheckOptionBuilder.Build();

            // Assert
            result.ResultStatusCodes.Should().NotBeNullOrEmpty();
        }

        [TestMethod]
        public void Build_ShouldNotModifyOtherStatusCodes()
        {
            // Act
            var result = HealthCheckOptionBuilder.Build();

            // Assert
            result.ResultStatusCodes[HealthStatus.Degraded].Should().Be(StatusCodes.Status200OK);
            result.ResultStatusCodes[HealthStatus.Unhealthy].Should().Be(StatusCodes.Status503ServiceUnavailable);
        }
    }
}