using EPR.CommonDataService.Api.Features.Pom;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.UnitTests.Features.Pom;

[ExcludeFromCodeCoverage]
[TestClass]
public class PomControllerTests
{
    private Mock<IGetPomRequestHandler> _mockRequestHandler = null!;
    private Mock<ILogger<PomController>> _mockLogger = null!;
    private PomController _controller = null!;

    [TestInitialize]
    public void Setup()
    {
        _mockRequestHandler = new Mock<IGetPomRequestHandler>();
        _mockLogger = new Mock<ILogger<PomController>>();
        _controller = BuildController();
    }

    private PomController BuildController()
    {
        var controller = new PomController(_mockRequestHandler.Object, _mockLogger.Object);

        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() };

        return controller;
    }

    private static List<OrganisationPomResponse> SampleRows() =>
    [
        new()
        {
            OrganisationId = 103844,
            OrganisationName = "Test Producer Ltd",
            SubmissionPeriod = "2024-P4",
            SubsidiaryId = "114897",
            PackagingType = "HH",
            PackagingMaterial = "OT",
            PackagingMaterialWeight = 334343,
            PackagingClass = "P1",
            PackagingActivity = "HL",
            FromCountry = "EN",
            SubmitterId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        }
    ];

    [TestMethod]
    public async Task Get_WhenRequestIsValid_ShouldReturnOkWithRows()
    {
        // Arrange
        var request = new GetPomRequest { OrganisationId = 103844, RelativeYear = 2025 };
        var rows = SampleRows();

        _mockRequestHandler
            .Setup(h => h.Handle(103844, 2025, null, It.IsAny<CancellationToken>()))
            .ReturnsAsync(rows);

        // Act
        var result = await _controller.Get(request, CancellationToken.None);

        // Assert
        result.Should().BeOfType<OkObjectResult>();
        var okResult = (OkObjectResult)result;
        okResult.Value.Should().BeEquivalentTo(rows);
    }

    [TestMethod]
    public async Task Get_WhenRelativeYearIsNull_ShouldPassNullToHandler()
    {
        // Arrange
        var request = new GetPomRequest { OrganisationId = 103844, RelativeYear = null };

        _mockRequestHandler
            .Setup(h => h.Handle(It.IsAny<int>(), It.IsAny<int?>(), It.IsAny<DateTimeOffset?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync([]);

        // Act
        await _controller.Get(request, CancellationToken.None);

        // Assert
        _mockRequestHandler.Verify(
            h => h.Handle(103844, null, null, It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [TestMethod]
    public async Task Get_WhenCutOffDateIsSupplied_ShouldParseAndPassItToHandler()
    {
        // Arrange
        var request = new GetPomRequest
        {
            OrganisationId = 103844,
            RelativeYear = 2025,
            CutOffDate = "2026-01-01"
        };

        _mockRequestHandler
            .Setup(h => h.Handle(It.IsAny<int>(), It.IsAny<int?>(), It.IsAny<DateTimeOffset?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync([]);

        // Act
        await _controller.Get(request, CancellationToken.None);

        // Assert
        _mockRequestHandler.Verify(
            h => h.Handle(103844, 2025, It.Is<DateTimeOffset?>(d => d != null), It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [TestMethod]
    public async Task Get_WhenOrganisationHasNoData_ShouldReturnOkWithEmptyArrayRatherThanNotFound()
    {
        // Arrange
        // An organisation that reported nothing chargeable is a real organisation with no rows,
        // and this endpoint cannot tell that apart from one that does not exist.
        var request = new GetPomRequest { OrganisationId = 999999, RelativeYear = 2025 };

        _mockRequestHandler
            .Setup(h => h.Handle(It.IsAny<int>(), It.IsAny<int?>(), It.IsAny<DateTimeOffset?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync([]);

        // Act
        var result = await _controller.Get(request, CancellationToken.None);

        // Assert
        result.Should().BeOfType<OkObjectResult>();
        var okResult = (OkObjectResult)result;
        okResult.Value.Should().BeAssignableTo<IReadOnlyCollection<OrganisationPomResponse>>()
            .Which.Should().BeEmpty();
    }
}