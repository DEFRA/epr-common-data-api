using System.Globalization;
using AutoFixture;
using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Entities;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

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
    public async Task GetApprovedSubmissions_WhenValidDateString_ReturnsOk()
    {
        // Arrange
        var expectedResponse = _fixture.Create<IList<ApprovedSubmissionEntity>>();

        _submissionsService
            .Setup(x => x.GetApprovedSubmissions(It.IsAny<DateTime>()))
            .ReturnsAsync(expectedResponse);

        // Act
        var result = await _submissionsController.GetApprovedSubmissions(DateTime.UtcNow.ToString(CultureInfo.InvariantCulture));

        // Assert
        result.Should().NotBeNull().And.BeOfType<OkObjectResult>();
        ((OkObjectResult)result).Value.Should().Be(expectedResponse);
    }

    [TestMethod]
    public async Task GetApprovedSubmissions_WhenInvalidDateString_ReturnsBadRequest()
    {
        // Arrange
        var expectedError = new Dictionary<string, string[]> { { "approvedAfterDateString", new[] { "Invalid datetime provided; please make sure it's a valid UTC datetime" } } };

        // Act
        var result = await _submissionsController.GetApprovedSubmissions("invalid date string");

        // Assert
        result.Should().NotBeNull().And.BeOfType<BadRequestObjectResult>();
        ((BadRequestObjectResult)result).Value.Should().BeEquivalentTo(expectedError);
    }

    [TestMethod]
    public async Task GetAggregatedPomData_WhenValidsubmissionIdString_ReturnsOk()
    {
        // Arrange
        var expectedResponse = _fixture.Create<IList<PomObligationEntity>>();

        _submissionsService
            .Setup(x => x.GetAggregatedPomData(It.IsAny<Guid>()))
            .ReturnsAsync(expectedResponse);

        // Act
        var result = await _submissionsController.GetAggregatedPomData(Guid.NewGuid().ToString());

        // Assert
        result.Should().NotBeNull().And.BeOfType<OkObjectResult>();
        ((OkObjectResult)result).Value.Should().Be(expectedResponse);
    }

    [TestMethod]
    public async Task GetAggregatedPomData_WhenInvalidsubmissionIdString_ReturnsBadRequest()
    {
        // Arrange
        var expectedError = new Dictionary<string, string[]> { { "submissionIdString", new[] { "Invalid GUID provided; please make sure it's a correctly formatted GUID" } } };

        // Act
        var result = await _submissionsController.GetAggregatedPomData("invalid Guid string");

        // Assert
        result.Should().NotBeNull().And.BeOfType<BadRequestObjectResult>();
        ((BadRequestObjectResult)result).Value.Should().BeEquivalentTo(expectedError);
    }
}