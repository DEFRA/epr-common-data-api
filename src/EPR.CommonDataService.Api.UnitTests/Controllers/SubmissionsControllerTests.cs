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
using System.Diagnostics.CodeAnalysis;
using System.Globalization;

namespace EPR.CommonDataService.Api.UnitTests.Controllers;

[ExcludeFromCodeCoverage]
[TestClass]
public class SubmissionsControllerTests
{
    private readonly Mock<ILogger<SubmissionsController>> _logger = new();
    private SubmissionsController _submissionsController = null!;
    private readonly Mock<ISubmissionsService> _mockSubmissionsService = new();
    private readonly Mock<IOptions<ApiConfig>> _apiConfigOptionsMock = new();
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

        ////TODO:: Update with ILateFeeService
        _submissionsController = new SubmissionsController(_mockSubmissionsService.Object, default, _apiConfigOptionsMock.Object, _logger.Object, configurationMock.Object)
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

        _mockSubmissionsService.Setup(service => service.GetSubmissionPomSummaries(request))
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

        _mockSubmissionsService.Setup(service => service.GetSubmissionRegistrationSummaries(request))
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

        _mockSubmissionsService
            .Setup(x => x.GetApprovedSubmissionsWithAggregatedPomData(It.IsAny<DateTime>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
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
        _mockSubmissionsService
            .Setup(x => x.GetApprovedSubmissionsWithAggregatedPomData(It.IsAny<DateTime>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()))
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

        _mockSubmissionsService.Setup(x => x.GetApprovedSubmissionsWithAggregatedPomData(It.IsAny<DateTime>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>())).ThrowsAsync(new TimeoutException(expectedErrorMessage));

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

        _mockSubmissionsService.Setup(x => x.GetApprovedSubmissionsWithAggregatedPomData(It.IsAny<DateTime>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>())).ThrowsAsync(new Exception(expectedErrorMessage));

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

        _mockSubmissionsService.Setup(x => x.GetOrganisationRegistrationSubmissionSummaries(1, It.IsAny<OrganisationRegistrationFilterRequest>())).Verifiable();

        await _submissionsController.GetOrganisationRegistrationSubmissions(1, request);

        _mockSubmissionsService.Verify(
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
        _mockSubmissionsService.Setup(x => x.GetOrganisationRegistrationSubmissionSummaries(1, It.IsAny<OrganisationRegistrationFilterRequest>())).Verifiable();

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

        _mockSubmissionsService.Setup(x => x.GetOrganisationRegistrationSubmissionSummaries(1, request)).Throws<TimeoutException>();

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

        _mockSubmissionsService.Setup(x => x.GetOrganisationRegistrationSubmissionSummaries(1, request)).Throws<Exception>();

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

        _mockSubmissionsService.Setup(x => x.GetOrganisationRegistrationSubmissionSummaries(1, request)).ReturnsAsync(innerResult);
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

        PaginatedResponse<OrganisationRegistrationSummaryDto>? innerResult = new PaginatedResponse<OrganisationRegistrationSummaryDto>
        {
            Items = [
            new()
            {
                SubmissionId = Guid.NewGuid()
            }],
            CurrentPage = 1,
            PageSize = 1,
            TotalItems = 1
        };

        _mockSubmissionsService.Setup(x => x.GetOrganisationRegistrationSubmissionSummaries(1, request)).ReturnsAsync(innerResult);
        var result = await _submissionsController.GetOrganisationRegistrationSubmissions(1, request);

        var properResult = result as OkObjectResult;
        properResult.Should().NotBeNull();
        properResult?.StatusCode.Should().Be(StatusCodes.Status200OK);
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissionDetails_WhenSubmissionId_IsNull_Returns_ReturnsValidationProblem()
    {
        // Arrange
        Guid? submissionId = null;
        var lateFeeCutOffDay = 1;
        var lateFeeCutOffMonth = 4;

        var result = await _submissionsController.GetOrganisationRegistrationSubmissionDetails(submissionId, lateFeeCutOffDay, lateFeeCutOffMonth);

        var properResult = result as ObjectResult;
        properResult.Should().NotBeNull();
        var resultValidations = properResult?.Value as ValidationProblemDetails;
        resultValidations.Should().NotBeNull();
        resultValidations?.Errors.ContainsKey("SubmissionId").Should().BeTrue();
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissionDetails_WillCall_ServiceServiceLayer()
    {
        // Arrange
        var request = new OrganisationRegistrationDetailRequest
        {
            SubmissionId = Guid.NewGuid(),
            LateFeeCutOffDay = 1,
            LateFeeCutOffMonth = 4
        };

        _mockSubmissionsService.Setup(x =>
            x.GetOrganisationRegistrationSubmissionDetails(
                It.IsAny<OrganisationRegistrationDetailRequest>()))
            .Verifiable();

        // Act
        await _submissionsController.GetOrganisationRegistrationSubmissionDetails(
            request.SubmissionId,
            request.LateFeeCutOffDay,
            request.LateFeeCutOffMonth);

        // Assert
        _mockSubmissionsService.Verify(x =>
            x.GetOrganisationRegistrationSubmissionDetails(
                It.IsAny<OrganisationRegistrationDetailRequest>())
            , Times.Once());
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissionDetails_WhenServiceThrowsTimeout_ReturnsGatewayTimeout()
    {
        // Arrange
        var request = new OrganisationRegistrationDetailRequest
        {
            SubmissionId = Guid.NewGuid(),
            LateFeeCutOffDay = 1,
            LateFeeCutOffMonth = 4
        };

        _mockSubmissionsService.Setup(x =>
            x.GetOrganisationRegistrationSubmissionDetails(
                It.IsAny<OrganisationRegistrationDetailRequest>()))
            .Throws<TimeoutException>();

        // Act
        var result = await _submissionsController.GetOrganisationRegistrationSubmissionDetails(
            request.SubmissionId,
            request.LateFeeCutOffDay,
            request.LateFeeCutOffMonth);

        var properResult = result as ObjectResult;
        properResult.Should().NotBeNull();
        properResult?.StatusCode.Should().Be(StatusCodes.Status504GatewayTimeout);
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissionDetails_WhenServiceThrowsException_Returns500Error()
    {
        // Arrange
        var request = new OrganisationRegistrationDetailRequest
        {
            SubmissionId = Guid.NewGuid(),
            LateFeeCutOffDay = 1,
            LateFeeCutOffMonth = 4
        };

        _mockSubmissionsService.Setup(x =>
            x.GetOrganisationRegistrationSubmissionDetails(
                It.IsAny<OrganisationRegistrationDetailRequest>()))
            .Throws<Exception>();

        var result = await _submissionsController.GetOrganisationRegistrationSubmissionDetails(
            request.SubmissionId,
            request.LateFeeCutOffDay,
            request.LateFeeCutOffMonth);

        var properResult = result as ObjectResult;
        properResult.Should().NotBeNull();
        properResult?.StatusCode.Should().Be(StatusCodes.Status500InternalServerError);
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissionDetails_WhenServiceReceivesResult_WillReturnOK()
    {
        // Arrange
        OrganisationRegistrationDetailsDto? innerResult = new()
        {
            SubmissionId = Guid.NewGuid()
        };

        OrganisationRegistrationDetailRequest request = new()
        {
            SubmissionId = Guid.NewGuid(),
            LateFeeCutOffDay = 1,
            LateFeeCutOffMonth = 4
        };

        _mockSubmissionsService.Setup(x =>
            x.GetOrganisationRegistrationSubmissionDetails(
                It.IsAny<OrganisationRegistrationDetailRequest>()))
            .ReturnsAsync(innerResult);

        var result = await _submissionsController.GetOrganisationRegistrationSubmissionDetails(
            request.SubmissionId,
            request.LateFeeCutOffDay,
            request.LateFeeCutOffMonth);

        var properResult = result as OkObjectResult;
        properResult.Should().NotBeNull();
        properResult?.StatusCode.Should().Be(StatusCodes.Status200OK);
    }

    [TestMethod]
    public async Task POMResubmission_PaycalParameters_ShouldReturnOk_WhenValidSubmissionExists()
    {
        // Arrange
        var submissionId = Guid.NewGuid();
        var complianceSchemeId = Guid.NewGuid();
        var expectedResult = new PomResubmissionPaycalParametersDto { MemberCount = 0, Reference = "Ref", ReferenceFieldAvailable = true };

        _mockSubmissionsService
            .Setup(s => s.GetResubmissionPaycalParameters(It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync(expectedResult);

        // Act
        var result = await _submissionsController.POMResubmission_PaycalParameters(submissionId, complianceSchemeId);

        // Assert
        result.Result.Should().BeOfType<OkObjectResult>()
            .Which.Value.Should().BeOfType<PomResubmissionPaycalParametersDto>();
    }

    [TestMethod]
    public async Task POMResubmission_PaycalParameters_ShouldReturnNoContent_WhenSubmissionNotFound()
    {
        // Arrange
        var submissionId = Guid.NewGuid();

        _mockSubmissionsService
            .Setup(s => s.GetResubmissionPaycalParameters(It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync(default(PomResubmissionPaycalParametersDto));

        // Act
        var result = await _submissionsController.POMResubmission_PaycalParameters(submissionId, null);

        // Assert
        result.Result.Should().BeOfType<NoContentResult>();
    }

    [TestMethod]
    public async Task POMResubmission_PaycalParameters_ShouldReturnPreconditionFailed_WhenReferenceFieldNotAvailable()
    {
        // Arrange
        var submissionId = Guid.NewGuid();
        var complianceSchemeId = Guid.NewGuid();
        var response = new PomResubmissionPaycalParametersDto { ReferenceFieldAvailable = false };

        _mockSubmissionsService
            .Setup(s => s.GetResubmissionPaycalParameters(It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync(response);

        // Act
        var result = await _submissionsController.POMResubmission_PaycalParameters(submissionId, complianceSchemeId);

        // Assert
        var objectResult = result.Result as ObjectResult;
        objectResult.Should().NotBeNull();
        objectResult!.StatusCode.Should().Be(StatusCodes.Status412PreconditionFailed);
        objectResult.Value.Should().Be("Db Schema isn't updated to include PomResubmission ReferenceNumber");
    }

    [TestMethod]
    public async Task POMResubmission_PaycalParameters_ShouldReturnPreconditionRequired_WhenReferenceNotAvailable()
    {
        // Arrange
        var submissionId = Guid.NewGuid();
        var complianceSchemeId = Guid.NewGuid();
        var response = new PomResubmissionPaycalParametersDto { ReferenceFieldAvailable = true };

        _mockSubmissionsService
            .Setup(s => s.GetResubmissionPaycalParameters(It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync(response);

        // Act
        var result = await _submissionsController.POMResubmission_PaycalParameters(submissionId, complianceSchemeId);

        // Assert
        var objectResult = result.Result as ObjectResult;
        objectResult.Should().NotBeNull();
        objectResult!.StatusCode.Should().Be(StatusCodes.Status428PreconditionRequired);
        objectResult.Value.Should().Be("No Reference number found for this submission.  Is Data Syncronised?");
    }

    [TestMethod]
    public async Task POMResubmission_PaycalParameters_ShouldReturnGatewayTimeout_WhenTimeoutOccurs()
    {
        // Arrange
        var submissionId = Guid.NewGuid();

        _mockSubmissionsService
            .Setup(s => s.GetResubmissionPaycalParameters(It.IsAny<string>(), It.IsAny<string>()))
            .ThrowsAsync(new TimeoutException("Operation timed out"));

        // Act
        var result = await _submissionsController.POMResubmission_PaycalParameters(submissionId, null);

        // Assert
        var objectResult = result.Result as ObjectResult;
        objectResult.Should().NotBeNull();
    }


    [TestMethod]
    public async Task POMResubmission_PaycalParameters_ShouldThrow_WhenSqlExceptionOccurrs()
    {
        // Arrange
        var submissionId = Guid.NewGuid();

        _mockSubmissionsService
            .Setup(s => s.GetResubmissionPaycalParameters(It.IsAny<string>(), It.IsAny<string>()))
            .ThrowsAsync(new Exception("DB exception"));

        // Act
        var result = await _submissionsController.POMResubmission_PaycalParameters(submissionId, null);

        // Assert
        var objectResult = result.Result as ObjectResult;
        objectResult.Should().NotBeNull();
    }

    [TestMethod]
    public async Task IsCosmosFileSynchronised_Should_Return_Ok_False_When_IsCosmosDataAvailable_Returns_Null()
    {
        // Arrange
        var fileId = Guid.NewGuid();
        _mockSubmissionsService
            .Setup(x => x.IsCosmosDataAvailable(null, It.IsAny<string>()))
            .ReturnsAsync((bool?)null);

        // Act
        var result = await _submissionsController.IsCosmosFileSynchronised(fileId);

        // Assert
        result.Result.Should().BeOfType<OkObjectResult>()
            .Which.Value.Should().Be(false);
    }

    [TestMethod]
    public async Task IsCosmosFileSynchronised_Should_Return_Ok_True_When_IsCosmosDataAvailable_Returns_True()
    {
        // Arrange
        var fileId = Guid.NewGuid();
        _mockSubmissionsService
            .Setup(x => x.IsCosmosDataAvailable(null, It.IsAny<string>()))
            .ReturnsAsync(true);

        // Act
        var result = await _submissionsController.IsCosmosFileSynchronised(fileId);

        // Assert
        result.Result.Should().BeOfType<OkObjectResult>()
            .Which.Value.Should().Be(true);
    }

    [TestMethod]
    public async Task IsCosmosFileSynchronised_Should_Return_Ok_False_When_IsCosmosDataAvailable_Returns_False()
    {
        // Arrange
        var fileId = Guid.NewGuid();
        _mockSubmissionsService
            .Setup(x => x.IsCosmosDataAvailable(null, It.IsAny<string>()))
            .ReturnsAsync(false);

        // Act
        var result = await _submissionsController.IsCosmosFileSynchronised(fileId);

        // Assert
        result.Result.Should().BeOfType<OkObjectResult>()
            .Which.Value.Should().Be(false);
    }

    [TestMethod]
    public async Task IsCosmosFileSynchronised_Should_Return_504_When_IsCosmosDataAvailable_Throws_TimeoutException()
    {
        // Arrange
        var fileId = Guid.NewGuid();
        _mockSubmissionsService
            .Setup(x => x.IsCosmosDataAvailable(null, It.IsAny<string>()))
            .ThrowsAsync(new TimeoutException("Request timed out"));

        // Act
        var result = await _submissionsController.IsCosmosFileSynchronised(fileId);

        // Assert
        result.Result.Should().BeOfType<ObjectResult>()
            .Which.StatusCode.Should().Be(504);
    }

    [TestMethod]
    public async Task IsCosmosFileSynchronised_Should_Return_500_When_IsCosmosDataAvailable_Throws_Exception()
    {
        // Arrange
        var fileId = Guid.NewGuid();
        _mockSubmissionsService
            .Setup(x => x.IsCosmosDataAvailable(null, It.IsAny<string>()))
            .ThrowsAsync(new Exception("Unexpected error"));

        // Act
        var result = await _submissionsController.IsCosmosFileSynchronised(fileId);

        // Assert
        result.Result.Should().BeOfType<ObjectResult>()
            .Which.StatusCode.Should().Be(500);
    }

    [TestMethod]
    public async Task IsSubmissionSynchronised_Should_Return_Ok_False_When_IsCosmosDataAvailable_Returns_Null()
    {
        // Arrange
        var submissionId = Guid.NewGuid();
        _mockSubmissionsService
            .Setup(x => x.IsCosmosDataAvailable(It.IsAny<string>(), null))
            .ReturnsAsync((bool?)null);

        // Act
        var result = await _submissionsController.IsSubmissionSynchronised(submissionId);

        // Assert
        result.Result.Should().BeOfType<OkObjectResult>()
            .Which.Value.Should().Be(false);
    }

    [TestMethod]
    public async Task IsSubmissionSynchronised_Should_Return_Ok_True_When_IsCosmosDataAvailable_Returns_True()
    {
        // Arrange
        var submissionId = Guid.NewGuid();
        _mockSubmissionsService
            .Setup(x => x.IsCosmosDataAvailable(It.IsAny<string>(), null))
            .ReturnsAsync(true);

        // Act
        var result = await _submissionsController.IsSubmissionSynchronised(submissionId);

        // Assert
        result.Result.Should().BeOfType<OkObjectResult>()
            .Which.Value.Should().Be(true);
    }

    [TestMethod]
    public async Task IsSubmissionSynchronised_Should_Return_Ok_False_When_IsCosmosDataAvailable_Returns_False()
    {
        // Arrange
        var submissionId = Guid.NewGuid();
        _mockSubmissionsService
            .Setup(x => x.IsCosmosDataAvailable(It.IsAny<string>(), null))
            .ReturnsAsync(false);

        // Act
        var result = await _submissionsController.IsSubmissionSynchronised(submissionId);

        // Assert
        result.Result.Should().BeOfType<OkObjectResult>()
            .Which.Value.Should().Be(false);
    }

    [TestMethod]
    public async Task IsSubmissionSynchronised_Should_Return_504_When_IsCosmosDataAvailable_Throws_TimeoutException()
    {
        // Arrange
        var submissionId = Guid.NewGuid();
        _mockSubmissionsService
            .Setup(x => x.IsCosmosDataAvailable(It.IsAny<string>(), null))
            .ThrowsAsync(new TimeoutException("Request timed out"));

        // Act
        var result = await _submissionsController.IsSubmissionSynchronised(submissionId);

        // Assert
        result.Result.Should().BeOfType<ObjectResult>()
            .Which.StatusCode.Should().Be(504);
    }

    [TestMethod]
    public async Task IsSubmissionSynchronised_Should_Return_500_When_IsCosmosDataAvailable_Throws_Exception()
    {
        // Arrange
        var submissionId = Guid.NewGuid();
        _mockSubmissionsService
            .Setup(x => x.IsCosmosDataAvailable(It.IsAny<string>(), null))
            .ThrowsAsync(new Exception("Unexpected error"));

        // Act
        var result = await _submissionsController.IsSubmissionSynchronised(submissionId);

        // Assert
        result.Result.Should().BeOfType<ObjectResult>()
            .Which.StatusCode.Should().Be(500);
    }
}
