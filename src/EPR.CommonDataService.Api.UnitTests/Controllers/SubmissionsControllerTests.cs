using AutoFixture;
using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Entities;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.Extensions.Options;
using System.Globalization;

namespace EPR.CommonDataService.Api.UnitTests.Controllers;

[TestClass]
public class SubmissionsControllerTests
{
    private SubmissionsController _submissionsController = null!;
    private readonly Mock<ISubmissionsService> _submissionsService = new();
    private readonly Mock<IOptions<ApiConfig>> _apiConfigOptionsMock = new();
    private IFixture _fixture;

    [TestInitialize]
    public void Setup()
    {
        _fixture = new Fixture();

        _apiConfigOptionsMock
            .Setup(x => x.Value)
            .Returns(new ApiConfig
            {
                BaseProblemTypePath = "https://dummytest/"
            });

        _submissionsController = new SubmissionsController(_submissionsService.Object,
            _apiConfigOptionsMock.Object)
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
            .Setup(x => x.GetApprovedSubmissionsWithAggregatedPomData(It.IsAny<DateTime>()))
            .ReturnsAsync(expectedResponse);

        // Act
        var result = await _submissionsController.GetApprovedSubmissionsWithAggregatedPomData(DateTime.UtcNow.ToString(CultureInfo.InvariantCulture));

        // Assert
        result.Should().NotBeNull().And.BeOfType<OkObjectResult>();
        ((OkObjectResult)result).Value.Should().Be(expectedResponse);
    }

    [TestMethod]
    public async Task GetApprovedSubmissionsWithAggregatedPomData_WhenNoApprovedSubmissionsForValidDate_ReturnsNotFound()
    {
        // Arrange
        var expectedErrorMessage = "The datetime provided did not return any submissions";

        _submissionsService
            .Setup(x => x.GetApprovedSubmissionsWithAggregatedPomData(It.IsAny<DateTime>()))
            .ReturnsAsync(new List<ApprovedSubmissionEntity>());

        // Act
        var result = await _submissionsController.GetApprovedSubmissionsWithAggregatedPomData(DateTime.UtcNow.ToString(CultureInfo.InvariantCulture));

        // Assert
        result.Should().NotBeNull().And.BeOfType<NotFoundObjectResult>();
        var notFoundResult = (NotFoundObjectResult)result;

        var modelState = notFoundResult.Value as ModelStateDictionary;

        modelState.Should().NotBeNull();
        modelState.ContainsKey("approvedAfterDateString").Should().BeTrue();

        var errors = modelState["approvedAfterDateString"].Errors;
        errors.Should().ContainSingle();
        errors.First().ErrorMessage.Should().Be(expectedErrorMessage);
    }

    [TestMethod]
    public async Task GetApprovedSubmissionsWithAggregatedPomData_WhenInvalidDateString_ReturnsBadRequest()
    {
        // Arrange
        var expectedError = new Dictionary<string, string[]> { { "approvedAfterDateString", new[] { "Invalid datetime provided; please make sure it's a valid UTC datetime" } } };

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

        _submissionsService.Setup(x => x.GetApprovedSubmissionsWithAggregatedPomData(It.IsAny<DateTime>())).ThrowsAsync(new TimeoutException(expectedErrorMessage));

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

        _submissionsService.Setup(x => x.GetApprovedSubmissionsWithAggregatedPomData(It.IsAny<DateTime>())).ThrowsAsync(new Exception(expectedErrorMessage));

        // Act
        var result = await _submissionsController.GetApprovedSubmissionsWithAggregatedPomData(DateTime.UtcNow.ToString(CultureInfo.InvariantCulture));

        // Assert
        result.Should().NotBeNull().And.BeOfType<ObjectResult>();
        var objectResult = (ObjectResult)result;
        objectResult.StatusCode.Should().Be(StatusCodes.Status500InternalServerError);
        objectResult.Value.Should().Be(expectedErrorMessage);
    }

}