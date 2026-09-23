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
            .Setup(h => h.Handle(2025, null))
            .Returns(pomResponses.ToAsyncEnumerable());

        // Act
        var result = _controller.StreamOut(request, CancellationToken.None);

        // Assert
        result.Should().BeOfType<NdJsonStreamResult<PomResponse>>();
    }
}
