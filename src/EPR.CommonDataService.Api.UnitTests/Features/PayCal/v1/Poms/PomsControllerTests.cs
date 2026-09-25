using System.Diagnostics.CodeAnalysis;
using EPR.CommonDataService.Api.Features.PayCal.v1.Poms;
using EPR.CommonDataService.Api.Features.PayCal.v1.Poms.StreamOut;
using EPR.CommonDataService.Api.Infrastructure;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace EPR.CommonDataService.Api.UnitTests.Features.PayCal.v1.Poms;

[ExcludeFromCodeCoverage]
[TestClass]
public class PomsControllerTests
{
    private Mock<IStreamPomsRequestHandler> _mockRequestHandler = null!;
    private Mock<ILogger<PomsController>> _mockLogger = null!;
    private PomsController _controller = null!;

    [TestInitialize]
    public void Setup()
    {
        _mockRequestHandler = new Mock<IStreamPomsRequestHandler>();
        _mockLogger = new Mock<ILogger<PomsController>>();

        _controller = new PomsController(
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
        var request = new StreamPomsRequest { RelativeYear = 2025, CutOffDate = null };

        var pomResponses = new List<PomResponse>
        {
            new()
            {
                SubmissionPeriod = "2024-P1",
                OrganisationId = 1,
                SubsidiaryId = null,
                PackagingType = "Household",
                PackagingMaterial = "Plastic",
                PackagingMaterialWeight = 100,
                PackagingClass = "ClassA",
                PackagingActivity = "Primary",
                SubmitterId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
            }
        };

        _mockRequestHandler
            .Setup(h => h.Handle(2025, null, CancellationToken.None))
            .Returns(pomResponses.ToAsyncEnumerable());

        // Act
        var result = _controller.StreamOut(request, CancellationToken.None);

        // Assert
        result.Should().BeOfType<NdJsonStreamResult<PomResponse>>();
    }

    [TestMethod]
    public async Task StreamOut_WhenStreamCompletesSuccessfully_ShouldLogCompletedSuccessfully()
    {
        // Arrange
        var request = new StreamPomsRequest { RelativeYear = 2025, CutOffDate = null };

        static async IAsyncEnumerable<PomResponse> GetRecords()
        {
            await Task.CompletedTask;
            yield return new PomResponse { OrganisationId = 1, SubmissionPeriod = "2024-P1" };
        }

        _mockRequestHandler
            .Setup(h => h.Handle(2025, null, CancellationToken.None))
            .Returns(GetRecords());

        _controller.HttpContext.Response.Body = new MemoryStream();

        // Act
        var result = (NdJsonStreamResult<PomResponse>)_controller.StreamOut(request, CancellationToken.None);
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
        var request = new StreamPomsRequest { RelativeYear = 2025, CutOffDate = null };
        var cts = new CancellationTokenSource();

        async IAsyncEnumerable<PomResponse> GetRecords()
        {
            yield return new PomResponse { OrganisationId = 1, SubmissionPeriod = "2024-P1" };
            await cts.CancelAsync();
            await Task.Delay(10, cts.Token); // throws OperationCanceledException
        }

        _mockRequestHandler
            .Setup(h => h.Handle(2025, null, CancellationToken.None))
            .Returns(GetRecords());

        _controller.HttpContext.Response.Body = new MemoryStream();
        _controller.HttpContext.RequestAborted = cts.Token;

        // Act
        var result = (NdJsonStreamResult<PomResponse>)_controller.StreamOut(request, CancellationToken.None);
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
        var request = new StreamPomsRequest { RelativeYear = 2025, CutOffDate = "2026-01-01" };

        _mockRequestHandler
            .Setup(h => h.Handle(It.IsAny<int>(), It.IsAny<DateTimeOffset?>(), It.IsAny<CancellationToken>()))
            .Returns(new List<PomResponse>().ToAsyncEnumerable());

        // Act
        _controller.StreamOut(request, CancellationToken.None);

        // Assert
        _mockRequestHandler.Verify(
            h => h.Handle(2025, It.Is<DateTimeOffset?>(d => d.HasValue), CancellationToken.None),
            Times.Once);
    }
}
