using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Core.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.UnitTests.Controllers;

[TestClass]
public class RegistrationFeeCalculationDetailsControllerTests
{
    private Mock<IRegistrationFeeCalculationDetailsService> _registrationFeeCalculationDetailsServiceMock = null!;
    private Mock<IOptions<ApiConfig>> _apiConfigOptionsMock = null!;
    private RegistrationFeeCalculationDetailsController _controller = null!;

    [TestInitialize]
    public void Setup()
    {
        _registrationFeeCalculationDetailsServiceMock = new Mock<IRegistrationFeeCalculationDetailsService>();
        _apiConfigOptionsMock = new Mock<IOptions<ApiConfig>>();

        _apiConfigOptionsMock
            .Setup(x => x.Value)
            .Returns(new ApiConfig
            {
                BaseProblemTypePath = "https://dummytest/"
            });

        _controller = new RegistrationFeeCalculationDetailsController(
            _apiConfigOptionsMock.Object,
            _registrationFeeCalculationDetailsServiceMock.Object
        );
    }

    [TestMethod]
    public async Task GetRegistrationFeeCalculationDetails_InvalidRequest_ReturnsBadRequest()
    {
        // Arrange
        // Act
        var result = await _controller.GetRegistrationFeeCalculationDetails(Guid.Empty);

        // Assert
        result.Should().BeOfType<BadRequestObjectResult>();
        (result as BadRequestObjectResult)!.Value.Should().Be("fileId is invalid");
    }

    [TestMethod]
    public async Task GetRegistrationFeeCalculationDetails_ValidRequest_NoResult_ReturnsNotFound()
    {
        // Arrange
        var fileId = Guid.NewGuid();

        _registrationFeeCalculationDetailsServiceMock
            .Setup(service => service.GetRegistrationFeeCalculationDetails(fileId))
            .ReturnsAsync((RegistrationFeeCalculationDetails[]) null!); // Simulating no result

        // Act
        var result = await _controller.GetRegistrationFeeCalculationDetails(fileId);

        // Assert
        result.Should().BeOfType<NoContentResult>();
    }

    [TestMethod]
    public async Task GetRegistrationFeeCalculationDetails_ValidRequest_WithResult_ReturnsOk()
    {
        // Arrange
        var fileId = Guid.NewGuid();

        var expectedResult = new[] { new RegistrationFeeCalculationDetails { OrganisationSize = "Large", NumberOfSubsidiaries = 10, NumberOfSubsidiariesBeingOnlineMarketPlace = 20, NumberOfLateSubsidiaries = 30, IsOnlineMarketplace = true, IsNewJoiner = false, NationId = 1, OrganisationId = "1234" } }; // Mock result

        _registrationFeeCalculationDetailsServiceMock
            .Setup(service => service.GetRegistrationFeeCalculationDetails(fileId))
            .ReturnsAsync(expectedResult);

        // Act
        var result = await _controller.GetRegistrationFeeCalculationDetails(fileId);

        // Assert
        result.Should().BeOfType<OkObjectResult>();
        (result as OkObjectResult)!.Value.Should().Be(expectedResult);
    }
}