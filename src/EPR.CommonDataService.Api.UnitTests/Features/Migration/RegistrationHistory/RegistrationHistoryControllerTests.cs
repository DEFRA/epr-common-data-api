using System.Diagnostics.CodeAnalysis;
using System.Reflection;
using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Api.Features.Migration.RegistrationHistory;
using EPR.CommonDataService.Api.Infrastructure;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Microsoft.FeatureManagement.Mvc;

namespace EPR.CommonDataService.Api.UnitTests.Features.Migration.RegistrationHistory;

[ExcludeFromCodeCoverage]
[TestClass]
public class RegistrationHistoryControllerTests
{
    private Mock<IStreamRegistrationHistoryRequestHandler> _mockRequestHandler = null!;
    private RegistrationHistoryController _controller = null!;

    [TestInitialize]
    public void Setup()
    {
        _mockRequestHandler = new Mock<IStreamRegistrationHistoryRequestHandler>();

        var mockApiConfig = new Mock<IOptions<ApiConfig>>();
        mockApiConfig
            .Setup(x => x.Value)
            .Returns(new ApiConfig { BaseProblemTypePath = "https://dummytest/" });

        _controller = new RegistrationHistoryController(
            _mockRequestHandler.Object,
            mockApiConfig.Object,
            new Mock<ILogger<RegistrationHistoryController>>().Object)
        {
            ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() }
        };
    }

    [TestMethod]
    public void StreamOut_ShouldReturnNdJsonStreamResultAndCallHandler()
    {
        // Arrange
        _mockRequestHandler
            .Setup(h => h.Handle())
            .Returns(new List<RegistrationHistoryResponse>
            {
                new() { SubmissionId = Guid.NewGuid().ToString(), EventType = "Submitted", EventTypeOrder = 1 }
            }.ToAsyncEnumerable());

        // Act
        var result = _controller.StreamOut();

        // Assert
        result.Should().BeOfType<NdJsonStreamResult<RegistrationHistoryResponse>>();
        _mockRequestHandler.Verify(h => h.Handle(), Times.Once);
    }

    [TestMethod]
    public void Controller_ShouldBeFeatureGatedByRegistrationMigrationEndpoint()
    {
        // Act
        var featureGate = typeof(RegistrationHistoryController).GetCustomAttribute<FeatureGateAttribute>();

        // Assert
        featureGate.Should().NotBeNull();
        featureGate!.Features.Should().ContainSingle().Which.Should().Be("RegistrationMigrationEndpoint");
    }

    [TestMethod]
    public void RegistrationHistorySql_ShouldLoadEmbeddedScriptEndingInFinalSelect()
    {
        // Act
        var sql = RegistrationHistorySql.Load();

        // Assert
        sql.Should().Contain("CREATE TABLE #Selected");
        sql.Should().Contain("DECLARE @BlobContainerName NVARCHAR(200) = N'registration-upload-container-recyclers';");
        sql.Should().Contain("AND bad.InContainer = 0");
        sql.Should().Contain("COALESCE(NULLIF(e.AppReferenceNumber, ''), NULLIF(s.AppReferenceNumber, '')) AS AppReferenceNumber");
        sql.Should().Contain("ORDER BY w.SubmissionId, ev.ReplayTs, ev.EventTypeOrder;");
        sql.Should().NotContain("{", "FromSqlRaw treats braces as parameter placeholders");
    }
}
