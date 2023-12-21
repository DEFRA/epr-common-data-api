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
        var request = _fixture.Create<PomSubmissionsSummariesRequest>();
        var serviceResponse = _fixture.Create<PaginatedResponse<PomSubmissionSummary>>();
        
        _submissionsService.Setup(service => service.GetSubmissionPomSummaries(request))
            .ReturnsAsync(serviceResponse);

        // Act
        var result = await _submissionsController.GetPomSubmissionsSummaries(request) as ObjectResult;

        // Assert
        result.Should().NotBeNull();
        result?.Value.Should().BeEquivalentTo(serviceResponse);
    }
}