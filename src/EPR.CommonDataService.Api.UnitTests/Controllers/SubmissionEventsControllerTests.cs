using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Api.Controllers;
using EPR.CommonDataService.Core.Models;
using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Entities;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Microsoft.Identity.Client;

namespace EPR.CommonDataService.Api.UnitTests.Controllers;

[TestClass]
public class SubmissionEventsControllerTests
{
    private SubmissionEventsController _submissionEventsController = null!;
    private readonly Mock<ISubmissionEventService> _submissionEventService = new();
    private readonly Mock<IOptions<ApiConfig>> _apiConfigOptionsMock = new();

    [TestInitialize]
    public void Setup()
    {
        _apiConfigOptionsMock
            .Setup(x => x.Value)
            .Returns(new ApiConfig
            {
                BaseProblemTypePath = "https://dummytest/"
            });

        _submissionEventsController = new SubmissionEventsController(_submissionEventService.Object, 
            _apiConfigOptionsMock.Object)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext()
            }
        };
    }
    
    [TestMethod]
    public async Task When_Last_Sync_Time_Is_Requested_Then_Return_Date_Time_As_Response()
    {
        var lastSyncTime = new SubmissionEventsLastSync
        {
            LastSyncTime = DateTime.Today
        };
        // Arrange
        _submissionEventService.Setup(service => service.GetLastSyncTimeAsync())
            .ReturnsAsync(lastSyncTime);

        // Act
        var result = await _submissionEventsController.GetLastSyncTime() as ObjectResult;

        // Assert
        result.Should().NotBeNull();
        result?.Value.Should().BeEquivalentTo(lastSyncTime);
    }
}