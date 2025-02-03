using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Core.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.UnitTests.Controllers;

[TestClass]
public class FeeCalculationDetailsControllerTests
{
    private Mock<IFeeCalculationDetailsService> _feeCalculationDetailsServiceMock = null!;
    private Mock<IOptions<ApiConfig>> _apiConfigOptionsMock = null!;
    private FeeCalculationDetailsController _controller = null!;

    [TestInitialize]
    public void Setup()
    {
        _feeCalculationDetailsServiceMock = new Mock<IFeeCalculationDetailsService>();
        _apiConfigOptionsMock = new Mock<IOptions<ApiConfig>>();

        _apiConfigOptionsMock
            .Setup(x => x.Value)
            .Returns(new ApiConfig
            {
                BaseProblemTypePath = "https://dummytest/"
            });

        _controller = new FeeCalculationDetailsController(
            _apiConfigOptionsMock.Object,
            _feeCalculationDetailsServiceMock.Object
        );
    }

    [TestMethod]
    public async Task GetFeeCalculationDetails_InvalidRequest_ReturnsBadRequest()
    {
        // Arrange
        // Act
        var result = await _controller.GetFeeCalculationDetails(Guid.Empty);

        // Assert
        result.Should().BeOfType<BadRequestObjectResult>();
        (result as BadRequestObjectResult)!.Value.Should().Be("fileId is invalid");
    }

    [TestMethod]
    public async Task GetFeeCalculationDetails_ValidRequest_NoResult_ReturnsNotFound()
    {
        // Arrange
        var fileId = Guid.NewGuid();

        _feeCalculationDetailsServiceMock
            .Setup(service => service.GetFeeCalculationDetails(fileId))
            .ReturnsAsync((FeeCalculationDetails[]) null!); // Simulating no result

        // Act
        var result = await _controller.GetFeeCalculationDetails(fileId);

        // Assert
        result.Should().BeOfType<NoContentResult>();
    }

    [TestMethod]
    public async Task GetFeeCalculationDetails_ValidRequest_WithResult_ReturnsOk()
    {
        // Arrange
        var fileId = Guid.NewGuid();

        var expectedResult = new[] { new FeeCalculationDetails { OrganisationSize = "Large", NumberOfSubsidiaries = 10, NumberOfSubsidiariesBeingOnlineMarketPlace = 20 } }; // Mock result

        _feeCalculationDetailsServiceMock
            .Setup(service => service.GetFeeCalculationDetails(fileId))
            .ReturnsAsync(expectedResult);

        // Act
        var result = await _controller.GetFeeCalculationDetails(fileId);

        // Assert
        result.Should().BeOfType<OkObjectResult>();
        (result as OkObjectResult)!.Value.Should().Be(expectedResult);
    }
}