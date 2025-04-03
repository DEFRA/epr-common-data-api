using AutoFixture;
using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Entities;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Microsoft.FeatureManagement;
using System.Diagnostics.CodeAnalysis;
using System.Globalization;

namespace EPR.CommonDataService.Api.UnitTests.Controllers;

[ExcludeFromCodeCoverage]
[TestClass]
public class SubmissionsControllerTests
{
    private readonly Mock<ILogger<SubmissionsController>> _logger = new();
    private SubmissionsController _submissionsController = null!;
    private readonly Mock<ISubmissionsService> _submissionsService = new();
    private readonly Mock<IOptions<ApiConfig>> _apiConfigOptionsMock = new();
    private readonly Mock<IFeatureManager> _mockFeatureManager = new();
    private Fixture _fixture = null!;

    [TestInitialize]
    public void Setup()
    {
        _fixture = new Fixture();

        _apiConfigOptionsMock
            .Setup(x => x.Value)
            .Returns(new ApiConfig
            {
                BaseProblemTypePath = "https://dummytest/",
                PomDataSubmissionPeriods = "P1,P4"
            });

        var configurationMock = new Mock<IConfiguration>();
        configurationMock.Setup(c => c["LogPrefix"]).Returns("[EPR.CommonDataService]");
        
        _submissionsController = new SubmissionsController(_submissionsService.Object, _apiConfigOptionsMock.Object, _logger.Object, configurationMock.Object,_mockFeatureManager.Object)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext()
            }
        };
    }

    [TestMethod]
    public async Task GetPomSubmissionsSummaries_ReturnsResponse()
    {
        // Arrange
        var request = _fixture.Create<SubmissionsSummariesRequest<RegulatorPomDecision>>();
        var serviceResponse = _fixture.Create<PaginatedResponse<PomSubmissionSummary>>();

        _submissionsService.Setup(service => service.GetSubmissionPomSummaries(request))
            .ReturnsAsync(serviceResponse);

        // Act
        var result = await _submissionsController.GetPomSubmissionsSummaries(request) as ObjectResult;

        // Assert
        result.Should().NotBeNull();
        result?.Value.Should().BeEquivalentTo(serviceResponse);
    }

    [TestMethod]
    public async Task GetPomSubmissionsSummaries_WhenEnableCsvDownloadFeatureFlagIsTrue_ReturnsResponse()
    {
        // Arrange
        var request = _fixture.Create<SubmissionsSummariesRequest<RegulatorPomDecision>>();
        var serviceResponse = _fixture.Create<PaginatedResponse<PomSubmissionSummaryWithFileFields>>();

        _mockFeatureManager.Setup(x => x.IsEnabledAsync(FeatureFlags.EnableCsvDownload)).ReturnsAsync(true);
        _submissionsService.Setup(service => service.GetSubmissionPomSummariesWithFileInfo(request))
            .ReturnsAsync(serviceResponse);

        // Act
        var result = await _submissionsController.GetPomSubmissionsSummaries(request) as ObjectResult;

        // Assert
        result.Should().NotBeNull();
        result?.Value.Should().BeEquivalentTo(serviceResponse);
    }

    [TestMethod]
    public async Task GetRegistrationSubmissionsSummaries_ReturnsResponse()
    {
        // Arrange
        var request = _fixture.Create<SubmissionsSummariesRequest<RegulatorRegistrationDecision>>();
        var serviceResponse = _fixture.Create<PaginatedResponse<RegistrationSubmissionSummary>>();

        _submissionsService.Setup(service => service.GetSubmissionRegistrationSummaries(request))
            .ReturnsAsync(serviceResponse);

        // Act
        var result = await _submissionsController.GetRegistrationsSubmissionsSummaries(request) as ObjectResult;

        // Assert
        result.Should().NotBeNull();
        result?.Value.Should().BeEquivalentTo(serviceResponse);
    }

    [TestMethod]
    public async Task GetApprovedSubmissionsWithAggregatedPomData_WhenValidDateString_ReturnsOk()
    {
        // Arrange
        var expectedResponse = _fixture.Create<IList<ApprovedSubmissionEntity>>();

        _submissionsService
            .Setup(x => x.GetApprovedSubmissionsWithAggregatedPomData(It.IsAny<DateTime>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync(expectedResponse);

        // Act
        var result = await _submissionsController.GetApprovedSubmissionsWithAggregatedPomData(DateTime.UtcNow.ToString(CultureInfo.InvariantCulture));

        // Assert
        result.Should().NotBeNull().And.BeOfType<OkObjectResult>();
        ((OkObjectResult)result).Value.Should().Be(expectedResponse);
    }

    [TestMethod]
    public async Task GetApprovedSubmissionsWithAggregatedPomData_WhenNoApprovedSubmissionsForValidDate_ReturnsNoContent()
    {
        // Arrange
        _submissionsService
            .Setup(x => x.GetApprovedSubmissionsWithAggregatedPomData(It.IsAny<DateTime>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync(new List<ApprovedSubmissionEntity>());

        // Act
        var result = await _submissionsController.GetApprovedSubmissionsWithAggregatedPomData(DateTime.UtcNow.ToString(CultureInfo.InvariantCulture));

        // Assert
        result.Should().NotBeNull().And.BeOfType<NoContentResult>();
    }

    [TestMethod]
    public async Task GetApprovedSubmissionsWithAggregatedPomData_WhenInvalidDateString_ReturnsBadRequest()
    {
        // Arrange
        string[] expectedErrorMessage = new[] { "Invalid datetime provided; please make sure it's a valid UTC datetime" };
        var expectedError = new Dictionary<string, string[]> { { "approvedAfterDateString", expectedErrorMessage } };

        // Act
        var result = await _submissionsController.GetApprovedSubmissionsWithAggregatedPomData("invalid date string");

        // Assert
        result.Should().NotBeNull().And.BeOfType<BadRequestObjectResult>();
        ((BadRequestObjectResult)result).Value.Should().BeEquivalentTo(expectedError);
    }

    [TestMethod]
    public async Task GetApprovedSubmissionsWithAggregatedPomData_WhenTimeoutExceptionThrown_ReturnsGatewayTimeout()
    {
        // Arrange
        var expectedErrorMessage = "The operation has timed out.";

        _submissionsService.Setup(x => x.GetApprovedSubmissionsWithAggregatedPomData(It.IsAny<DateTime>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>())).ThrowsAsync(new TimeoutException(expectedErrorMessage));

        // Act
        var result = await _submissionsController.GetApprovedSubmissionsWithAggregatedPomData(DateTime.UtcNow.ToString(CultureInfo.InvariantCulture));

        // Assert
        result.Should().NotBeNull().And.BeOfType<ObjectResult>();
        var objectResult = (ObjectResult)result;
        objectResult.StatusCode.Should().Be(StatusCodes.Status504GatewayTimeout);
        objectResult.Value.Should().Be(expectedErrorMessage);
    }


    [TestMethod]
    public async Task GetApprovedSubmissionsWithAggregatedPomData_WhenExceptionThrown_ReturnsInternalServerError()
    {
        // Arrange
        var expectedErrorMessage = "An unexpected error occurred.";

        _submissionsService.Setup(x => x.GetApprovedSubmissionsWithAggregatedPomData(It.IsAny<DateTime>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>())).ThrowsAsync(new Exception(expectedErrorMessage));

        // Act
        var result = await _submissionsController.GetApprovedSubmissionsWithAggregatedPomData(DateTime.UtcNow.ToString(CultureInfo.InvariantCulture));

        // Assert
        result.Should().NotBeNull().And.BeOfType<ObjectResult>();
        var objectResult = (ObjectResult)result;
        objectResult.StatusCode.Should().Be(StatusCodes.Status500InternalServerError);
        objectResult.Value.Should().Be(expectedErrorMessage);
    }


    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissions_WhenNationId_IsInvalid_Returns_ReturnsValidationProblem()
    {
        var request = _fixture
                    .Build<OrganisationRegistrationFilterRequest>()
                    .With(x => x.PageSize, 20)
                    .With(x => x.PageNumber, 1)
                    .Create();

        var result = await _submissionsController.GetOrganisationRegistrationSubmissions(0, request);

        var properResult = result as ObjectResult;
        properResult.Should().NotBeNull();
        var resultValidations = properResult?.Value as ValidationProblemDetails;
        resultValidations.Should().NotBeNull();
        resultValidations?.Errors.ContainsKey("NationId").Should().BeTrue();
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissions_WhenNoSubmissions_CallServiceLayer()
    {
        var request = _fixture
                    .Build<OrganisationRegistrationFilterRequest>()
                    .With(x => x.PageSize, 20)
                    .With(x => x.PageNumber, 1)
                    .Create();

        _submissionsService.Setup(x => x.GetOrganisationRegistrationSubmissionSummaries(1, It.IsAny<OrganisationRegistrationFilterRequest>())).Verifiable();

        await _submissionsController.GetOrganisationRegistrationSubmissions(1, request);

        _submissionsService.Verify(
            x => x.GetOrganisationRegistrationSubmissionSummaries(
                1,
                It.IsAny<OrganisationRegistrationFilterRequest>()
            ),
            Times.Once()
        );
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissions_WhenSuppliedModelIsInvalid_ReturnsValidationError()
    {
        var request = _fixture
                    .Build<OrganisationRegistrationFilterRequest>()
                    .With(x => x.PageSize, 1)
                    .With(x => x.PageNumber, 1)
                    .Create();

        _submissionsController.ModelState.AddModelError("PageSize", "PageSize is required");
        _submissionsService.Setup(x => x.GetOrganisationRegistrationSubmissionSummaries(1,It.IsAny<OrganisationRegistrationFilterRequest>())).Verifiable();

        var result = await _submissionsController.GetOrganisationRegistrationSubmissions(1, request);

        var properResult = result as ObjectResult;
        properResult.Should().NotBeNull();
        var resultValidations = properResult?.Value as ValidationProblemDetails;
        resultValidations.Should().NotBeNull();
        resultValidations?.Errors.ContainsKey("PageSize").Should().BeTrue();
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissions_WhenServiceThrowsTimeout_ReturnsGatewayTimeout()
    {
        var request = _fixture
                    .Build<OrganisationRegistrationFilterRequest>()
                    .With(x => x.PageSize, 1)
                    .With(x => x.PageNumber, 1)
                    .Create();

        _submissionsService.Setup(x => x.GetOrganisationRegistrationSubmissionSummaries(1, request)).Throws<TimeoutException>();

        var result = await _submissionsController.GetOrganisationRegistrationSubmissions(1, request);

        var properResult = result as ObjectResult;
        properResult.Should().NotBeNull();
        properResult?.StatusCode.Should().Be(StatusCodes.Status504GatewayTimeout);
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissions_WhenServiceThrowsException_Returns500Error()
    {
        var request = _fixture
                    .Build<OrganisationRegistrationFilterRequest>()
                    .With(x => x.PageSize, 1)
                    .With(x => x.PageNumber, 1)
                    .Create();

        _submissionsService.Setup(x => x.GetOrganisationRegistrationSubmissionSummaries(1, request)).Throws<Exception>();

        var result = await _submissionsController.GetOrganisationRegistrationSubmissions(1, request);

        var properResult = result as ObjectResult;
        properResult.Should().NotBeNull();
        properResult?.StatusCode.Should().Be(StatusCodes.Status500InternalServerError);
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissions_WhenServiceReceivesNoResult_WillReturnNoContentResponse()
    {
        var request = _fixture
                    .Build<OrganisationRegistrationFilterRequest>()
                    .With(x => x.PageSize, 1)
                    .With(x => x.PageNumber, 1)
                    .Create();

        PaginatedResponse<OrganisationRegistrationSummaryDto>? innerResult = new PaginatedResponse<OrganisationRegistrationSummaryDto> { Items = [], CurrentPage = 1, PageSize = 1, TotalItems = 0 };

        _submissionsService.Setup(x => x.GetOrganisationRegistrationSubmissionSummaries(1, request)).ReturnsAsync(innerResult);
        var result = await _submissionsController.GetOrganisationRegistrationSubmissions(1, request);

        var properResult = result as NoContentResult;
        properResult.Should().NotBeNull();
        properResult?.StatusCode.Should().Be(StatusCodes.Status204NoContent);
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissions_WhenServiceReceivesResult_WillReturnOK()
    {
        var request = _fixture
                    .Build<OrganisationRegistrationFilterRequest>()
                    .With(x => x.PageSize, 1)
                    .With(x => x.PageNumber, 1)
                    .Create();

        PaginatedResponse<OrganisationRegistrationSummaryDto>? innerResult = new PaginatedResponse<OrganisationRegistrationSummaryDto> { Items = [
            new() {
                SubmissionId = Guid.NewGuid()
            }], 
            CurrentPage = 1, PageSize = 1, TotalItems = 1 };

        _submissionsService.Setup(x => x.GetOrganisationRegistrationSubmissionSummaries(1, request)).ReturnsAsync(innerResult);
        var result = await _submissionsController.GetOrganisationRegistrationSubmissions(1, request);

        var properResult = result as OkObjectResult;
        properResult.Should().NotBeNull();
        properResult?.StatusCode.Should().Be(StatusCodes.Status200OK);
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissionDetails_WhenSubmissionId_IsNull_Returns_ReturnsValidationProblem()
    {
        Guid? request = null;

        var result = await _submissionsController.GetOrganisationRegistrationSubmissionDetails(request);

        var properResult = result as ObjectResult;
        properResult.Should().NotBeNull();
        var resultValidations = properResult?.Value as ValidationProblemDetails;
        resultValidations.Should().NotBeNull();
        resultValidations?.Errors.ContainsKey("SubmissionId").Should().BeTrue();
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissionDetails_WillCall_ServiceServiceLayer()
    {
        var request = new OrganisationRegistrationDetailRequest { SubmissionId = Guid.NewGuid() };
        
        _submissionsService.Setup(x => x.GetOrganisationRegistrationSubmissionDetails(It.IsAny<OrganisationRegistrationDetailRequest>())).Verifiable();
        
        await _submissionsController.GetOrganisationRegistrationSubmissionDetails(request.SubmissionId);

        _submissionsService.Verify(
                    x => x.GetOrganisationRegistrationSubmissionDetails(
                        It.IsAny<OrganisationRegistrationDetailRequest>()
                    ),
                    Times.Once()
                );
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissionDetails_WhenServiceThrowsTimeout_ReturnsGatewayTimeout()
    {
        var request = new OrganisationRegistrationDetailRequest { SubmissionId = Guid.NewGuid() };

        _submissionsService.Setup(x => x.GetOrganisationRegistrationSubmissionDetails(It.IsAny<OrganisationRegistrationDetailRequest>())).Throws<TimeoutException>();

        var result = await _submissionsController.GetOrganisationRegistrationSubmissionDetails(request.SubmissionId);

        var properResult = result as ObjectResult;
        properResult.Should().NotBeNull();
        properResult?.StatusCode.Should().Be(StatusCodes.Status504GatewayTimeout);
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissionDetails_WhenServiceThrowsException_Returns500Error()
    {
        var request = new OrganisationRegistrationDetailRequest { SubmissionId = Guid.NewGuid() };

        _submissionsService.Setup(x => x.GetOrganisationRegistrationSubmissionDetails(It.IsAny<OrganisationRegistrationDetailRequest>())).Throws<Exception>();

        var result = await _submissionsController.GetOrganisationRegistrationSubmissionDetails(request.SubmissionId);

        var properResult = result as ObjectResult;
        properResult.Should().NotBeNull();
        properResult?.StatusCode.Should().Be(StatusCodes.Status500InternalServerError);
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissionDetails_WhenServiceReceivesResult_WillReturnOK()
    {
        OrganisationRegistrationDetailsDto? innerResult = new()
        {
            SubmissionId = Guid.NewGuid()
        };
        OrganisationRegistrationDetailRequest request = new()
        {
            SubmissionId = Guid.NewGuid()
        };

        _submissionsService.Setup(x => x.GetOrganisationRegistrationSubmissionDetails(It.IsAny<OrganisationRegistrationDetailRequest>())).ReturnsAsync(innerResult);
        var result = await _submissionsController.GetOrganisationRegistrationSubmissionDetails(request.SubmissionId);

        var properResult = result as OkObjectResult;
        properResult.Should().NotBeNull();
        properResult?.StatusCode.Should().Be(StatusCodes.Status200OK);
    }
}
