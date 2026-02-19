using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Api.Features.PayCal.Poms;
using EPR.CommonDataService.Api.Features.PayCal.Poms.StreamOut;
using EPR.CommonDataService.Api.Infrastructure;
using FluentValidation;
using FluentValidation.Results;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.UnitTests.Features.PayCal.Poms;

[ExcludeFromCodeCoverage]
[TestClass]
public class PomsControllerTests
{
    private Mock<IStreamPomsRequestHandler> _mockRequestHandler = null!;
    private Mock<IValidator<StreamPomsRequest>> _mockValidator = null!;
    private Mock<IOptions<ApiConfig>> _mockApiConfig = null!;
    private Mock<ILogger<PomsController>> _mockLogger = null!;
    private PomsController _controller = null!;

    [TestInitialize]
    public void Setup()
    {
        _mockRequestHandler = new Mock<IStreamPomsRequestHandler>();
        _mockValidator = new Mock<IValidator<StreamPomsRequest>>();
        _mockLogger = new Mock<ILogger<PomsController>>();
        _mockApiConfig = new Mock<IOptions<ApiConfig>>();

        _mockApiConfig
            .Setup(x => x.Value)
            .Returns(new ApiConfig
            {
                BaseProblemTypePath = "https://dummytest/"
            });

        _controller = new PomsController(
            _mockRequestHandler.Object,
            _mockValidator.Object,
            _mockApiConfig.Object,
            _mockLogger.Object)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext()
            }
        };
    }

    [TestMethod]
    public async Task StreamOut_WhenRequestIsValid_ShouldReturnNdJsonStreamResult()
    {
        // Arrange
        var request = new StreamPomsRequest { RelativeYear = 2025 };

        _mockValidator
            .Setup(v => v.ValidateAsync(request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult());

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
            .Setup(h => h.Handle(request))
            .Returns(pomResponses.ToAsyncEnumerable());

        // Act
        var result = await _controller.StreamOut(request, CancellationToken.None);

        // Assert
        result.Should().BeOfType<NdJsonStreamResult<PomResponse>>();
    }

    [TestMethod]
    public async Task StreamOut_WhenRequestIsInvalid_ShouldReturnValidationProblem()
    {
        // Arrange
        var request = new StreamPomsRequest { RelativeYear = null };

        var validationFailures = new List<ValidationFailure>
        {
            new("SubmissionYear", "SubmissionYear is required")
        };

        _mockValidator
            .Setup(v => v.ValidateAsync(request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult(validationFailures));

        // Act
        var result = await _controller.StreamOut(request, CancellationToken.None);

        // Assert
        result.Should().BeOfType<ObjectResult>();
        var objectResult = (ObjectResult)result;
        objectResult.Value.Should().BeOfType<ValidationProblemDetails>();
    }

    [TestMethod]
    public async Task StreamOut_WhenMultipleValidationErrors_ShouldReturnAllErrors()
    {
        // Arrange
        var request = new StreamPomsRequest { RelativeYear = 2000 };

        var validationFailures = new List<ValidationFailure>
        {
            new("SubmissionYear", "SubmissionYear must be greater than or equal to 2024"),
            new("SubmissionYear", "Invalid year format")
        };

        _mockValidator
            .Setup(v => v.ValidateAsync(request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult(validationFailures));

        // Act
        var result = await _controller.StreamOut(request, CancellationToken.None);

        // Assert
        result.Should().BeOfType<ObjectResult>();
        var objectResult = (ObjectResult)result;
        var problemDetails = objectResult.Value as ValidationProblemDetails;
        problemDetails.Should().NotBeNull();
        problemDetails!.Errors.Should().ContainKey("SubmissionYear");
    }

    [TestMethod]
    public async Task StreamOut_WhenValidRequest_ShouldReturnNdJsonStreamResultAndCallHandler()
    {
        // Arrange
        var request = new StreamPomsRequest { RelativeYear = 2025 };

        _mockValidator
            .Setup(v => v.ValidateAsync(request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult());

        _mockRequestHandler
            .Setup(h => h.Handle(It.IsAny<StreamPomsRequest>()))
            .Returns(AsyncEnumerable.Empty<PomResponse>());

        // Act
        var result = await _controller.StreamOut(request, CancellationToken.None);

        // Assert
        result.Should().BeOfType<NdJsonStreamResult<PomResponse>>();
        _mockValidator.Verify(
            v => v.ValidateAsync(request, It.IsAny<CancellationToken>()),
            Times.Once);
        _mockRequestHandler.Verify(
            h => h.Handle(It.Is<StreamPomsRequest>(r => r.RelativeYear == 2025)),
            Times.Once);
    }

    [TestMethod]
    public async Task StreamOut_WhenValidationFails_ShouldNotCallHandler()
    {
        // Arrange
        var request = new StreamPomsRequest { RelativeYear = null };

        _mockValidator
            .Setup(v => v.ValidateAsync(request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult(new List<ValidationFailure>
            {
                new("SubmissionYear", "Required")
            }));

        // Act
        await _controller.StreamOut(request, CancellationToken.None);

        // Assert
        _mockRequestHandler.Verify(
            h => h.Handle(It.IsAny<StreamPomsRequest>()),
            Times.Never);
    }
}
