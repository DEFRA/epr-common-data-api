using System.Diagnostics.CodeAnalysis;
using EPR.CommonDataService.Api.Features.PayCal.v1.Organisations;
using EPR.CommonDataService.Api.Features.PayCal.v1.Organisations.StreamOut;
using EPR.CommonDataService.Api.Infrastructure;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace EPR.CommonDataService.Api.UnitTests.Features.PayCal.v1.Organisations;

[ExcludeFromCodeCoverage]
[TestClass]
public class OrganisationsControllerTests
{
    private Mock<IStreamOrganisationsRequestHandler> _mockRequestHandler = null!;
    private Mock<ILogger<OrganisationsController>> _mockLogger = null!;
    private OrganisationsController _controller = null!;

    [TestInitialize]
    public void Setup()
    {
        _mockRequestHandler = new Mock<IStreamOrganisationsRequestHandler>();
        _mockLogger = new Mock<ILogger<OrganisationsController>>();

        _controller = new OrganisationsController(
            _mockRequestHandler.Object,
            _mockLogger.Object)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext()
            }
        };
    }

    [TestMethod]
    public void StreamOut_ShouldReturnNdJsonStreamResult()
    {
        // Arrange
        var request = new StreamOrganisationsRequest { RelativeYear = 2025, CutOffDate = null };

        var orgResponses = new List<OrganisationResponse>
        {
            new()
            {
                OrganisationId = 1,
                SubsidiaryId = null,
                OrganisationName = "Test Org",
                TradingName = "Test Trading",
                StatusCode = "Active",
                ErrorCode = null,
                JoinerDate = "2024-01-01",
                LeaverDate = null,
                ObligationStatus = "Obligated",
                NumDaysObligated = 365,
                SubmitterId = "b2c3d4e5-f6a7-8901-bcde-f12345678901"
            }
        };

        _mockRequestHandler
            .Setup(h => h.Handle(2025, null, CancellationToken.None))
            .Returns(orgResponses.ToAsyncEnumerable());

        // Act
        var result = _controller.StreamOut(request, CancellationToken.None);

        // Assert
        result.Should().BeOfType<NdJsonStreamResult<OrganisationResponse>>();
    }

    [TestMethod]
    public async Task StreamOut_WhenStreamCompletesSuccessfully_ShouldLogCompletedSuccessfully()
    {
        // Arrange
        var request = new StreamOrganisationsRequest { RelativeYear = 2025, CutOffDate = null };

        static async IAsyncEnumerable<OrganisationResponse> GetRecords()
        {
            await Task.CompletedTask;
            yield return new OrganisationResponse { OrganisationId = 1, OrganisationName = "Test Org" };
        }

        _mockRequestHandler
            .Setup(h => h.Handle(2025, null, CancellationToken.None))
            .Returns(GetRecords());

        _controller.HttpContext.Response.Body = new MemoryStream();

        // Act
        var result = (NdJsonStreamResult<OrganisationResponse>)_controller.StreamOut(request, CancellationToken.None);
        await result.ExecuteResultAsync(new ActionContext { HttpContext = _controller.HttpContext });

        // Assert
        _mockLogger.Verify(
            logger => logger.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((state, _) => state.ToString()!.Contains("Completed successfully")),
                It.IsAny<Exception>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [TestMethod]
    public async Task StreamOut_WhenStreamIsAbortedByClient_ShouldLogAbortedByClient()
    {
        // Arrange
        var request = new StreamOrganisationsRequest { RelativeYear = 2025, CutOffDate = null };
        var cts = new CancellationTokenSource();

        async IAsyncEnumerable<OrganisationResponse> GetRecords()
        {
            yield return new OrganisationResponse { OrganisationId = 1, OrganisationName = "Test Org" };
            await cts.CancelAsync();
            await Task.Delay(10, cts.Token); // throws OperationCanceledException
        }

        _mockRequestHandler
            .Setup(h => h.Handle(2025, null, CancellationToken.None))
            .Returns(GetRecords());

        _controller.HttpContext.Response.Body = new MemoryStream();
        _controller.HttpContext.RequestAborted = cts.Token;

        // Act
        var result = (NdJsonStreamResult<OrganisationResponse>)_controller.StreamOut(request, CancellationToken.None);
        await result.ExecuteResultAsync(new ActionContext { HttpContext = _controller.HttpContext });

        // Assert
        _mockLogger.Verify(
            logger => logger.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((state, _) => state.ToString()!.Contains("Aborted by client")),
                It.IsAny<Exception>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);

        cts.Dispose();
    }

    [TestMethod]
    public void StreamOut_WhenCutOffDateIsSupplied_ShouldParseAndPassToHandler()
    {
        // Arrange
        var request = new StreamOrganisationsRequest { RelativeYear = 2025, CutOffDate = "2026-01-01" };

        _mockRequestHandler
            .Setup(h => h.Handle(It.IsAny<int>(), It.IsAny<DateTimeOffset?>(), It.IsAny<CancellationToken>()))
            .Returns(new List<OrganisationResponse>().ToAsyncEnumerable());

        // Act
        _controller.StreamOut(request, CancellationToken.None);

        // Assert
        _mockRequestHandler.Verify(
            h => h.Handle(2025, It.Is<DateTimeOffset?>(d => d.HasValue), CancellationToken.None),
            Times.Once);
    }
}
