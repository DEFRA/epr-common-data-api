using EPR.CommonDataService.Core.Models.Response;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace EPR.CommonDataService.Api.UnitTests.Controllers;

public partial class SubmissionsControllerTests
{
    #region Producer Paycal

    [TestMethod]
    public async Task ProducerPayCalParameters_Should_Log_And_Return_ValidationProblem_When_SubmissionId_IsInvalid() 
    {
        // Arrange

        // Act
        var result = await _submissionsController.GetOrganisationRegistrationSubmissionProducerPayCalParameters(Guid.Empty, false, null!) as ObjectResult;

        // Assert
        AssertProblemDetails(result, "submissionId", "SubmissionId must be a valid Guid", "GetOrganisationRegistrationSubmissionProducerPayCalParameters: Invalid SubmissionId provided");
    }

    [TestMethod]
    public async Task ProducerPayCalParameters_Should_Log_And_Return_ValidationProblem_When_QueryParams_IsInvalid()
    {
        // Arrange

        // Act
        var result = await _submissionsController.GetOrganisationRegistrationSubmissionProducerPayCalParameters(Guid.NewGuid(), false, null!) as ObjectResult;

        // Assert
        AssertProblemDetails(result, "queryParams", "Must have QueryParams", "GetOrganisationRegistrationSubmissionProducerPayCalParameters: Invalid QueryParams provided");
    }

    [TestMethod]
    public async Task ProducerPayCalParameters_Should_Log_And_Return_Status_On_Timeout_Exception()
    {
        // Arrange
        var request = new Dictionary<string, string>
        {
            { $"LateFeeCutOffMonth", "4" },
            { $"LateFeeCutOffDay", "1" }
        };
        _mockSubmissionsService.Setup(r => r.GetProducerPaycalParametersAsync(It.IsAny<Guid>(), It.IsAny<bool>(), It.IsAny<Guid>())).ThrowsAsync(new TimeoutException("Timeout"));

        // Act
        var result = await _submissionsController.GetOrganisationRegistrationSubmissionProducerPayCalParameters(Guid.NewGuid(), false, request) as ObjectResult;

        // Assert
        Assert.IsNotNull(result);
        result.StatusCode.Should().Be(504);
        _logger.Verify(logger =>
             logger.Log(
                 LogLevel.Error,
                 It.IsAny<EventId>(),
                 It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains(": SubmissionsController - GetOrganisationRegistrationSubmissionProducerPayCalParameters: The SubmissionId caused a timeout exception.")),
                 It.IsAny<TimeoutException>(),
                 It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
             Times.Once);
    }

    [TestMethod]
    public async Task ProducerPayCalParameters_Should_Log_And_Return_Status_On_Exception()
    {
        // Arrange
        var request = new Dictionary<string, string>
        {
            { $"LateFeeCutOffMonth", "4" },
            { $"LateFeeCutOffDay", "1" }
        };
        _mockSubmissionsService.Setup(r => r.GetProducerPaycalParametersAsync(It.IsAny<Guid>(), It.IsAny<bool>(), It.IsAny<Guid>())).ThrowsAsync(new Exception("Exception"));

        // Act
        var result = await _submissionsController.GetOrganisationRegistrationSubmissionProducerPayCalParameters(Guid.NewGuid(), false, request) as ObjectResult;

        // Assert
        Assert.IsNotNull(result);
        result.StatusCode.Should().Be(500);
        _logger.Verify(logger =>
             logger.Log(
                 LogLevel.Error,
                 It.IsAny<EventId>(),
                 It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains(": SubmissionsController - GetOrganisationRegistrationSubmissionProducerPayCalParameters: The SubmissionId caused an exception.")),
                 It.IsAny<Exception>(),
                 It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
             Times.Once);
    }

    [TestMethod]
    public async Task ProducerPayCalParameters_Should_Return_JsonResult_With_LateFee_Updated()
    {
        // Arrange
        var request = new Dictionary<string, string>
        {
            { $"LateFeeCutOffMonth", "4" },
            { $"LateFeeCutOffDay", "1" }
        };
        var response = new ProducerPaycalParametersResponse
        {
            EarliestSubmissionDate = DateTime.UtcNow
        };

        _mockSubmissionsService.Setup(r => r.GetProducerPaycalParametersAsync(It.IsAny<Guid>(), It.IsAny<bool>(), It.IsAny<Guid>())).ReturnsAsync(response);
        _mockLateFeeService.Setup(r => r.UpdateLateFeeFlag(It.IsAny<IDictionary<string, string>>(), It.IsAny<ProducerPaycalParametersResponse>())).Returns(response);

        // Act
        var result = await _submissionsController.GetOrganisationRegistrationSubmissionProducerPayCalParameters(Guid.NewGuid(), false, request) as JsonResult;

        // Assert
        Assert.IsNotNull(result);
        result.Value.Should().NotBeNull();
        result.Value.As<ProducerPaycalParametersResponse>().Should().NotBeNull();
    }

    #endregion

    #region Cso Paycal

    [TestMethod]
    public async Task CsoPayCalParameters_Should_Log_And_Return_ValidationProblem_When_SubmissionId_IsInvalid()
    {
        // Arrange

        // Act
        var result = await _submissionsController.GetOrganisationRegistrationSubmissionCsoPayCalParameters(Guid.Empty, false, null!) as ObjectResult;

        // Assert
        AssertProblemDetails(result, "submissionId", "SubmissionId must be a valid Guid", "GetOrganisationRegistrationSubmissionCsoPayCalParameters: Invalid SubmissionId provided");
    }

    [TestMethod]
    public async Task CsoPayCalParameters_Should_Log_And_Return_ValidationProblem_When_QueryParams_IsInvalid()
    {
        // Arrange

        // Act
        var result = await _submissionsController.GetOrganisationRegistrationSubmissionCsoPayCalParameters(Guid.NewGuid(), false, null!) as ObjectResult;

        // Assert
        AssertProblemDetails(result, "queryParams", "Must have QueryParams", "GetOrganisationRegistrationSubmissionCsoPayCalParameters: Invalid QueryParams provided");
    }

    [TestMethod]
    public async Task CsoPayCalParameters_Should_Log_And_Return_Status_On_Timeout_Exception()
    {
        // Arrange
        var request = new Dictionary<string, string>
        {
            { $"LateFeeCutOffMonth", "4" },
            { $"LateFeeCutOffDay", "1" }
        };
        _mockSubmissionsService.Setup(r => r.GetCsoPaycalParametersAsync(It.IsAny<Guid>(), It.IsAny<bool>(), It.IsAny<Guid>())).ThrowsAsync(new TimeoutException("Timeout"));

        // Act
        var result = await _submissionsController.GetOrganisationRegistrationSubmissionCsoPayCalParameters(Guid.NewGuid(), false, request) as ObjectResult;

        // Assert
        Assert.IsNotNull(result);
        result.StatusCode.Should().Be(504);
        _logger.Verify(logger =>
             logger.Log(
                 LogLevel.Error,
                 It.IsAny<EventId>(),
                 It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains(": SubmissionsController - GetOrganisationRegistrationSubmissionCsoPayCalParameters: The SubmissionId caused a timeout exception.")),
                 It.IsAny<TimeoutException>(),
                 It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
             Times.Once);
    }

    [TestMethod]
    public async Task CsoPayCalParameters_Should_Log_And_Return_Status_On_Exception()
    {
        // Arrange
        var request = new Dictionary<string, string>
        {
            { $"LateFeeCutOffMonth", "4" },
            { $"LateFeeCutOffDay", "1" }
        };
        _mockSubmissionsService.Setup(r => r.GetCsoPaycalParametersAsync(It.IsAny<Guid>(), It.IsAny<bool>(), It.IsAny<Guid>())).ThrowsAsync(new Exception("Exception"));

        // Act
        var result = await _submissionsController.GetOrganisationRegistrationSubmissionCsoPayCalParameters(Guid.NewGuid(), false, request) as ObjectResult;

        // Assert
        Assert.IsNotNull(result);
        result.StatusCode.Should().Be(500);
        _logger.Verify(logger =>
             logger.Log(
                 LogLevel.Error,
                 It.IsAny<EventId>(),
                 It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains(": SubmissionsController - GetOrganisationRegistrationSubmissionCsoPayCalParameters: The SubmissionId caused an exception.")),
                 It.IsAny<Exception>(),
                 It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
             Times.Once);
    }

    [TestMethod]
    public async Task CsoPayCalParameters_Should_Return_JsonResult_With_LateFee_Updated()
    {
        // Arrange
        var request = new Dictionary<string, string>
        {
            { $"LateFeeCutOffMonth", "4" },
            { $"LateFeeCutOffDay", "1" }
        };
        var response = new List<CsoPaycalParametersResponse>
        {
            new() { EarliestSubmissionDate = DateTime.UtcNow }
        };

        _mockSubmissionsService.Setup(r => r.GetCsoPaycalParametersAsync(It.IsAny<Guid>(), It.IsAny<bool>(), It.IsAny<Guid>())).ReturnsAsync(response);
        _mockLateFeeService.Setup(r => r.UpdateLateFeeFlag(It.IsAny<IDictionary<string, string>>(), It.IsAny<IList<CsoPaycalParametersResponse>>())).Returns(response);

        // Act
        var result = await _submissionsController.GetOrganisationRegistrationSubmissionCsoPayCalParameters(Guid.NewGuid(), false, request) as JsonResult;

        // Assert
        Assert.IsNotNull(result);
        result.Value.Should().NotBeNull();
        result.Value.As<IList<CsoPaycalParametersResponse>>().Should().NotBeNull();
    }

    #endregion

    [TestMethod]
    public async Task SubDetailsPart_Should_Log_And_Return_ValidationProblem_When_SubmissionId_IsInvalid()
    {
        // Arrange

        // Act
        var result = await _submissionsController.GetOrganisationRegistrationSubmissionDetailsPart(Guid.Empty) as ObjectResult;

        // Assert
        AssertProblemDetails(result, "submissionId", "SubmissionId must be a valid Guid", "GetOrganisationRegistrationSubmissionDetailsPart: Invalid SubmissionId provided");
    }

    [TestMethod]
    public async Task SubDetailsPart_Should_Log_And_Return_NoContent_When_Submission_IsNull()
    {
        // Arrange
        _mockSubmissionsService.Setup(r => r.GetOrganisationRegistrationSubmissionDetailsAsync(It.IsAny<Guid>())).ReturnsAsync(default(OrganisationRegistrationSubmissionDetailsResponse)!);

        // Act
        var result = await _submissionsController.GetOrganisationRegistrationSubmissionDetailsPart(Guid.NewGuid()) as NoContentResult;

        // Assert
        Assert.IsNotNull(result);
        result.StatusCode.Should().Be(204);
        _logger.Verify(logger =>
              logger.Log(
                  LogLevel.Error,
                  It.IsAny<EventId>(),
                  It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("SubmissionsController - GetOrganisationRegistrationSubmissionDetailsPart: The SubmissionId provided did not return a submission.")),
                  It.IsAny<Exception>(),
                  It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
              Times.Once);
    }

    [TestMethod]
    public async Task SubDetailsPart_Should_Log_And_Return_Status_On_Timeout_Exception()
    {
        // Arrange
        _mockSubmissionsService.Setup(r => r.GetOrganisationRegistrationSubmissionDetailsAsync(It.IsAny<Guid>())).ThrowsAsync(new TimeoutException("Timeout"));

        // Act
        var result = await _submissionsController.GetOrganisationRegistrationSubmissionDetailsPart(Guid.NewGuid()) as ObjectResult;

        // Assert
        Assert.IsNotNull(result);
        result.StatusCode.Should().Be(504);
        _logger.Verify(logger =>
             logger.Log(
                 LogLevel.Error,
                 It.IsAny<EventId>(),
                 It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains(": SubmissionsController - GetOrganisationRegistrationSubmissionDetailsPart: The SubmissionId caused a timeout exception.")),
                 It.IsAny<TimeoutException>(),
                 It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
             Times.Once);
    }

    [TestMethod]
    public async Task SubDetailsPart_Should_Log_And_Return_Status_On_Exception()
    {
        // Arrange
        _mockSubmissionsService.Setup(r => r.GetOrganisationRegistrationSubmissionDetailsAsync(It.IsAny<Guid>())).ThrowsAsync(new Exception("Exception"));

        // Act
        var result = await _submissionsController.GetOrganisationRegistrationSubmissionDetailsPart(Guid.NewGuid()) as ObjectResult;

        // Assert
        Assert.IsNotNull(result);
        result.StatusCode.Should().Be(500);
        _logger.Verify(logger =>
             logger.Log(
                 LogLevel.Error,
                 It.IsAny<EventId>(),
                 It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains(": SubmissionsController - GetOrganisationRegistrationSubmissionDetailsPart: The SubmissionId caused an exception.")),
                 It.IsAny<Exception>(),
                 It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
             Times.Once);
    }

    [TestMethod]
    public async Task SubDetailsPart_Should_Return_JsonResult_With_LateFee_Updated()
    {
        // Arrange
        var response = new OrganisationRegistrationSubmissionDetailsResponse
        {
            SubmissionId = Guid.NewGuid()
        };

        _mockSubmissionsService.Setup(r => r.GetOrganisationRegistrationSubmissionDetailsAsync(It.IsAny<Guid>())).ReturnsAsync(response);

        // Act
        var result = await _submissionsController.GetOrganisationRegistrationSubmissionDetailsPart(Guid.NewGuid()) as OkObjectResult;

        // Assert
        Assert.IsNotNull(result);
        result.Value.Should().NotBeNull();
        result.Value.As<OrganisationRegistrationSubmissionDetailsResponse>().Should().NotBeNull();
    }

    private void AssertProblemDetails(ObjectResult? result, string errorKey, string errorValue, string loggingText)
    {
        Assert.IsNotNull(result);
        var problemDetails = result.Value as ValidationProblemDetails;
        Assert.IsNotNull(problemDetails);
        problemDetails.Errors.Count.Should().Be(1);
        problemDetails.Errors.First().Key.Should().Be(errorKey);
        problemDetails.Errors.First().Value[0].Should().Be(errorValue);
        _logger.Verify(logger =>
               logger.Log(
                   LogLevel.Error,
                   It.IsAny<EventId>(),
                   It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains($": SubmissionsController - {loggingText}")),
                   It.IsAny<Exception>(),
                   It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
               Times.Once);
    }
}