using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Api.Features.PayCal.Organisations;
using EPR.CommonDataService.Api.Features.PayCal.Organisations.StreamOut;
using EPR.CommonDataService.Api.Infrastructure;
using FluentValidation;
using FluentValidation.Results;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.UnitTests.Features.PayCal.Organisations;

[ExcludeFromCodeCoverage]
[TestClass]
public class OrganisationsControllerTests
{
    private Mock<IStreamOrganisationsRequestHandler> _mockRequestHandler = null!;
    private Mock<IValidator<StreamOrganisationsRequest>> _mockValidator = null!;
    private Mock<IOptions<ApiConfig>> _mockApiConfig = null!;
    private Mock<ILogger<OrganisationsController>> _mockLogger = null!;
    private OrganisationsController _controller = null!;

    [TestInitialize]
    public void Setup()
    {
        _mockRequestHandler = new Mock<IStreamOrganisationsRequestHandler>();
        _mockValidator = new Mock<IValidator<StreamOrganisationsRequest>>();
        _mockLogger = new Mock<ILogger<OrganisationsController>>();
        _mockApiConfig = new Mock<IOptions<ApiConfig>>();

        _mockApiConfig
            .Setup(x => x.Value)
            .Returns(new ApiConfig
            {
                BaseProblemTypePath = "https://dummytest/"
            });

        _controller = new OrganisationsController(
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
        var request = new StreamOrganisationsRequest { RelativeYear = 2025 };

        _mockValidator
            .Setup(v => v.ValidateAsync(request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult());

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
            .Setup(h => h.Handle(request))
            .Returns(orgResponses.ToAsyncEnumerable());

        // Act
        var result = await _controller.StreamOut(request, CancellationToken.None);

        // Assert
        result.Should().BeOfType<NdJsonStreamResult<OrganisationResponse>>();
    }

    [TestMethod]
    public async Task StreamOut_WhenRequestIsInvalid_ShouldReturnValidationProblem()
    {
        // Arrange
        var request = new StreamOrganisationsRequest { RelativeYear = null };

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
        var request = new StreamOrganisationsRequest { RelativeYear = 2000 };

        var validationFailures = new List<ValidationFailure>
        {
            new("SubmissionYear", "SubmissionYear must be greater than or equal to 2023"),
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
        var request = new StreamOrganisationsRequest { RelativeYear = 2025 };

        _mockValidator
            .Setup(v => v.ValidateAsync(request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult());

        _mockRequestHandler
            .Setup(h => h.Handle(It.IsAny<StreamOrganisationsRequest>()))
            .Returns(AsyncEnumerable.Empty<OrganisationResponse>());

        // Act
        var result = await _controller.StreamOut(request, CancellationToken.None);

        // Assert
        result.Should().BeOfType<NdJsonStreamResult<OrganisationResponse>>();
        _mockValidator.Verify(
            v => v.ValidateAsync(request, It.IsAny<CancellationToken>()),
            Times.Once);
        _mockRequestHandler.Verify(
            h => h.Handle(It.Is<StreamOrganisationsRequest>(r => r.RelativeYear == 2025)),
            Times.Once);
    }

    [TestMethod]
    public async Task StreamOut_WhenValidationFails_ShouldNotCallHandler()
    {
        // Arrange
        var request = new StreamOrganisationsRequest { RelativeYear = null };

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
            h => h.Handle(It.IsAny<StreamOrganisationsRequest>()),
            Times.Never);
    }
}