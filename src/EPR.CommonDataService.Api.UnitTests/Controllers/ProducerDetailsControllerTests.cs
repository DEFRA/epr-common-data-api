using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Core.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.UnitTests.Controllers;

[TestClass]
public class ProducerDetailsControllerTests
{
    private Mock<IProducerDetailsService> _producerDetailsServiceMock = null!;
    private Mock<IOptions<ApiConfig>> _apiConfigOptionsMock = null!;
    private ProducerDetailsController _controller = null!;

    [TestInitialize]
    public void Setup()
    {
        _producerDetailsServiceMock = new Mock<IProducerDetailsService>();
        _apiConfigOptionsMock = new Mock<IOptions<ApiConfig>>();

        _apiConfigOptionsMock
            .Setup(x => x.Value)
            .Returns(new ApiConfig
            {
                BaseProblemTypePath = "https://dummytest/"
            });

        _controller = new ProducerDetailsController(
            _apiConfigOptionsMock.Object,
            _producerDetailsServiceMock.Object
        );
    }

    [TestMethod]
    public async Task GetProducerDetails_InvalidRequest_ReturnsBadRequest()
    {
        // Arrange
        // Act
        var result = await _controller.GetProducerDetails(0);

        // Assert
        result.Should().BeOfType<BadRequestObjectResult>();
        (result as BadRequestObjectResult)!.Value.Should().Be("OrganisationId is invalid");
    }
    [TestMethod]
    public async Task GetProducerDetails_InvalidFormatRequest_ReturnsBadRequest()
    {
        // Arrange
        // Act
        var result = await _controller.GetProducerDetails(-1);

        // Assert
        result.Should().BeOfType<BadRequestObjectResult>();
        (result as BadRequestObjectResult)!.Value.Should().Be("OrganisationId is invalid");
    }

    [TestMethod]
    public async Task GetProducerDetails_ValidRequest_NoResult_ReturnsNotFound()
    {
        // Arrange
        const int OrganisationId = 1234;

        _producerDetailsServiceMock
            .Setup(service => service.GetProducerDetails(OrganisationId))
            .ReturnsAsync((GetProducerDetailsResponse)null!); // Simulating no result

        // Act
        var result = await _controller.GetProducerDetails(OrganisationId);

        // Assert
        result.Should().BeOfType<NoContentResult>();
    }

    [TestMethod]
    public async Task GetProducerDetails_ValidRequest_WithResult_ReturnsOk()
    {
        // Arrange
        const int OrganisationId = 1234;

        var expectedResult = new GetProducerDetailsResponse { ProducerSize = "Large", NumberOfSubsidiaries = 10, NumberOfSubsidiariesBeingOnlineMarketPlace = 20 }; // Mock result

        _producerDetailsServiceMock
            .Setup(service => service.GetProducerDetails(OrganisationId))
            .ReturnsAsync(expectedResult);

        // Act
        var result = await _controller.GetProducerDetails(OrganisationId);

        // Assert
        result.Should().BeOfType<OkObjectResult>();
        (result as OkObjectResult)!.Value.Should().Be(expectedResult);
    }
}