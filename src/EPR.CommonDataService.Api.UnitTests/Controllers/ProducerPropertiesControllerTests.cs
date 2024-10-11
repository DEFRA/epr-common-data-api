using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Core.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.UnitTests.Controllers;

[TestClass]
public class ProducerPropertiesControllerTests
{
    private Mock<IProducerPropertiesService> _producerPropertiesServiceMock;
    private Mock<IOptions<ApiConfig>> _apiConfigOptionsMock;
    private ProducerPropertiesController _controller;

    [TestInitialize]
    public void Setup()
    {
        _producerPropertiesServiceMock = new Mock<IProducerPropertiesService>();
        _apiConfigOptionsMock = new Mock<IOptions<ApiConfig>>();

        _apiConfigOptionsMock
            .Setup(x => x.Value)
            .Returns(new ApiConfig
            {
                BaseProblemTypePath = "https://dummytest/"
            });

        _controller = new ProducerPropertiesController(
            _apiConfigOptionsMock.Object,
            _producerPropertiesServiceMock.Object
        );
    }

    [TestMethod]
    public async Task GetProducerSize_InvalidRequest_ReturnsBadRequest()
    {
        // Arrange
        // Act
        var result = await _controller.GetProducerSize(null);

        // Assert
        result.Should().BeOfType<BadRequestObjectResult>();
        (result as BadRequestObjectResult)!.Value.Should().Be("OrganisationId is invalid");
    }

    [TestMethod]
    public async Task GetProducerSize_ValidRequest_NoResult_ReturnsNotFound()
    {
        // Arrange
        var request = new GetProducerSizeRequest
        {
            OrganisationId = Guid.NewGuid()
        };

        _producerPropertiesServiceMock
            .Setup(service => service.GetProducerSize(request))
            .ReturnsAsync((GetProducerSizeResponse)null); // Simulating no result

        // Act
        var result = await _controller.GetProducerSize(request);

        // Assert
        result.Should().BeOfType<NotFoundResult>();
    }

    [TestMethod]
    public async Task GetProducerSize_ValidRequest_WithResult_ReturnsOk()
    {
        // Arrange
        var organisationId = Guid.NewGuid();
        var request = new GetProducerSizeRequest
        {
            OrganisationId = organisationId
        };

        var expectedResult = new GetProducerSizeResponse { ProducerSize = "Large", OrganisationId = organisationId }; // Mock result

        _producerPropertiesServiceMock
            .Setup(service => service.GetProducerSize(request))
            .ReturnsAsync(expectedResult);

        // Act
        var result = await _controller.GetProducerSize(request);

        // Assert
        result.Should().BeOfType<OkObjectResult>();
        (result as OkObjectResult)!.Value.Should().Be(expectedResult);
    }
}