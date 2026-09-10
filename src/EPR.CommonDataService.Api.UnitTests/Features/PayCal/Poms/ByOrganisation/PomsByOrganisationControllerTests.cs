using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Api.Features.PayCal.Poms.ByOrganisation;
using FluentValidation;
using FluentValidation.Results;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.UnitTests.Features.PayCal.Poms.ByOrganisation;

[ExcludeFromCodeCoverage]
[TestClass]
public class PomsByOrganisationControllerTests
{
    private Mock<IGetOrganisationPomsRequestHandler> _mockRequestHandler = null!;
    private Mock<IValidator<GetOrganisationPomsRequest>> _mockValidator = null!;
    private Mock<IOptions<ApiConfig>> _mockApiConfig = null!;
    private Mock<ILogger<PomsByOrganisationController>> _mockLogger = null!;
    private PomsByOrganisationController _controller = null!;

    [TestInitialize]
    public void Setup()
    {
        _mockRequestHandler = new Mock<IGetOrganisationPomsRequestHandler>();
        _mockValidator = new Mock<IValidator<GetOrganisationPomsRequest>>();
        _mockLogger = new Mock<ILogger<PomsByOrganisationController>>();
        _mockApiConfig = new Mock<IOptions<ApiConfig>>();
        _mockApiConfig.Setup(x => x.Value).Returns(new ApiConfig { BaseProblemTypePath = "https://dummytest/" });

        _controller = BuildController();
    }

    private PomsByOrganisationController BuildController()
    {
        var controller = new PomsByOrganisationController(
            _mockRequestHandler.Object, _mockValidator.Object, _mockApiConfig.Object, _mockLogger.Object);

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
    public async Task GetByOrganisation_WhenRequestIsValid_ShouldReturnOkWithRows()
    {
        // Arrange
        var request = new GetOrganisationPomsRequest { OrganisationId = 103844, RelativeYear = 2025 };
        var rows = SampleRows();

        _mockValidator
            .Setup(v => v.ValidateAsync(request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult());

        _mockRequestHandler
            .Setup(h => h.Handle(103844, 2025, null, It.IsAny<CancellationToken>()))
            .ReturnsAsync(rows);

        // Act
        var result = await _controller.GetByOrganisation(request, CancellationToken.None);

        // Assert
        result.Should().BeOfType<OkObjectResult>();
        var okResult = (OkObjectResult)result;
        okResult.Value.Should().BeEquivalentTo(rows);
    }

    [TestMethod]
    public async Task GetByOrganisation_WhenRelativeYearIsNull_ShouldPassNullToHandler()
    {
        // Arrange
        var request = new GetOrganisationPomsRequest { OrganisationId = 103844, RelativeYear = null };

        _mockValidator
            .Setup(v => v.ValidateAsync(request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult());

        _mockRequestHandler
            .Setup(h => h.Handle(It.IsAny<int>(), It.IsAny<int?>(), It.IsAny<DateTimeOffset?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync([]);

        // Act
        await _controller.GetByOrganisation(request, CancellationToken.None);

        // Assert
        _mockRequestHandler.Verify(
            h => h.Handle(103844, null, null, It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [TestMethod]
    public async Task GetByOrganisation_WhenCutOffDateIsSupplied_ShouldParseAndPassItToHandler()
    {
        // Arrange
        var request = new GetOrganisationPomsRequest
        {
            OrganisationId = 103844,
            RelativeYear = 2025,
            CutOffDate = "2026-01-01"
        };

        _mockValidator
            .Setup(v => v.ValidateAsync(request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult());

        _mockRequestHandler
            .Setup(h => h.Handle(It.IsAny<int>(), It.IsAny<int?>(), It.IsAny<DateTimeOffset?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync([]);

        // Act
        await _controller.GetByOrganisation(request, CancellationToken.None);

        // Assert
        _mockRequestHandler.Verify(
            h => h.Handle(103844, 2025, It.Is<DateTimeOffset?>(d => d != null), It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [TestMethod]
    public async Task GetByOrganisation_WhenOrganisationHasNoData_ShouldReturnOkWithEmptyArrayRatherThanNotFound()
    {
        // Arrange
        // An organisation that reported nothing chargeable is a real organisation with no rows,
        // and this endpoint cannot tell that apart from one that does not exist.
        var request = new GetOrganisationPomsRequest { OrganisationId = 999999, RelativeYear = 2025 };

        _mockValidator
            .Setup(v => v.ValidateAsync(request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult());

        _mockRequestHandler
            .Setup(h => h.Handle(It.IsAny<int>(), It.IsAny<int?>(), It.IsAny<DateTimeOffset?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync([]);

        // Act
        var result = await _controller.GetByOrganisation(request, CancellationToken.None);

        // Assert
        result.Should().BeOfType<OkObjectResult>();
        var okResult = (OkObjectResult)result;
        okResult.Value.Should().BeAssignableTo<IReadOnlyCollection<OrganisationPomResponse>>()
            .Which.Should().BeEmpty();
    }

    [TestMethod]
    public async Task GetByOrganisation_WhenRequestIsInvalid_ShouldReturnValidationProblem()
    {
        // Arrange
        var request = new GetOrganisationPomsRequest { OrganisationId = null };

        var validationFailures = new List<ValidationFailure>
        {
            new("OrganisationId", "OrganisationId is required")
        };

        _mockValidator
            .Setup(v => v.ValidateAsync(request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult(validationFailures));

        // Act
        var result = await _controller.GetByOrganisation(request, CancellationToken.None);

        // Assert
        result.Should().BeOfType<ObjectResult>();
        var objectResult = (ObjectResult)result;
        objectResult.Value.Should().BeOfType<ValidationProblemDetails>();
    }

    [TestMethod]
    public async Task GetByOrganisation_WhenRequestIsInvalid_ShouldNotCallTheHandler()
    {
        // Arrange
        // The procedure is expensive, so an invalid request must be rejected before it runs.
        var request = new GetOrganisationPomsRequest { OrganisationId = null };

        _mockValidator
            .Setup(v => v.ValidateAsync(request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult(
            [
                new ValidationFailure("OrganisationId", "OrganisationId is required")
            ]));

        // Act
        await _controller.GetByOrganisation(request, CancellationToken.None);

        // Assert
        _mockRequestHandler.Verify(
            h => h.Handle(It.IsAny<int>(), It.IsAny<int?>(), It.IsAny<DateTimeOffset?>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [TestMethod]
    public async Task GetByOrganisation_WhenMultipleValidationErrors_ShouldReturnAllErrors()
    {
        // Arrange
        var request = new GetOrganisationPomsRequest { OrganisationId = 0, RelativeYear = 2000 };

        var validationFailures = new List<ValidationFailure>
        {
            new("OrganisationId", "OrganisationId must be greater than 0"),
            new("RelativeYear", "RelativeYear must be greater than or equal to 2025")
        };

        _mockValidator
            .Setup(v => v.ValidateAsync(request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult(validationFailures));

        // Act
        var result = await _controller.GetByOrganisation(request, CancellationToken.None);

        // Assert
        var objectResult = (ObjectResult)result;
        var problemDetails = objectResult.Value as ValidationProblemDetails;
        problemDetails.Should().NotBeNull();
        problemDetails!.Errors.Should().ContainKey("OrganisationId");
        problemDetails.Errors.Should().ContainKey("RelativeYear");
    }
}
