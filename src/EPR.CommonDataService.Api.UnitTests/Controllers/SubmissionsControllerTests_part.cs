using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace EPR.CommonDataService.Api.UnitTests.Controllers;

public partial class SubmissionsControllerTests
{
    [TestMethod]
    public async Task PayCalParameters_Should_Log_And_Return_ValidationProblem_When_SubmissionId_IsInvalid() 
    {
        // Arrange

        // Act
        var result = await _submissionsController.GetOrganisationRegistrationSubmissionPayCalParameters(Guid.Empty, null!) as ObjectResult;

        // Assert
        Assert.IsNotNull(result);
        var problemDetails = result.Value as ValidationProblemDetails;
        Assert.IsNotNull(problemDetails);
        problemDetails.Errors.Count.Should().Be(1);
        problemDetails.Errors.First().Key.Should().Be("submissionId");
        problemDetails.Errors.First().Value[0].Should().Be("SubmissionId must be a valid Guid");
        _logger.Verify(logger =>
               logger.Log(
                   LogLevel.Error,
                   It.IsAny<EventId>(),
                   It.Is<It.IsAnyType>((v, t) => v.ToString().Contains(": SubmissionsController - GetOrganisationRegistrationSubmissionPayCalParameters: Invalid SubmissionId provided")),
                   It.IsAny<Exception>(),
                   It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
               Times.Once);
    }

    [TestMethod]
    public async Task PayCalParameters_Should_Log_And_Return_ValidationProblem_When_QueryParams_IsInvalid()
    {
        // Arrange

        // Act
        var result = await _submissionsController.GetOrganisationRegistrationSubmissionPayCalParameters(Guid.NewGuid(), null!) as ObjectResult;

        // Assert
        Assert.IsNotNull(result);
        var problemDetails = result.Value as ValidationProblemDetails;
        Assert.IsNotNull(problemDetails);
        problemDetails.Errors.Count.Should().Be(1);
        problemDetails.Errors.First().Key.Should().Be("queryParams");
        problemDetails.Errors.First().Value[0].Should().Be("Must have QueryParams");
        _logger.Verify(logger =>
              logger.Log(
                  LogLevel.Error,
                  It.IsAny<EventId>(),
                  It.Is<It.IsAnyType>((v, t) => v.ToString().Contains(": SubmissionsController - GetOrganisationRegistrationSubmissionPayCalParameters: Invalid QueryParams provided")),
                  It.IsAny<Exception>(),
                  It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
              Times.Once);
    }

    [TestMethod]
    public async Task PayCalParameters_Should_Log_And_Return_Status_On_Timeout_Exception()
    {
        // Arrange

        // Act

        // Assert
    }

    [TestMethod]
    public async Task PayCalParameters_Should_Log_And_Return_Status_On_Exception()
    {
        // Arrange

        // Act

        // Assert
    }

    [TestMethod]
    public async Task PayCalParameters_Should_Return_JsonResult_With_LateFee_Updated()
    {
        // Arrange

        // Act

        // Assert
    }
}