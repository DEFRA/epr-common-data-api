using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Core.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.UnitTests.Controllers;

[TestClass]
public class CompanyDetailsControllerTests
{
    private Mock<ICompanyDetailsService> _companyDetailsServiceMock;
    private Mock<IOptions<ApiConfig>> _apiConfigOptionsMock;
    private CompanyDetailsController _controller;

    [TestInitialize]
    public void Setup()
    {
        _companyDetailsServiceMock = new Mock<ICompanyDetailsService>();
        _apiConfigOptionsMock = new Mock<IOptions<ApiConfig>>();

        _apiConfigOptionsMock
            .Setup(x => x.Value)
            .Returns(new ApiConfig
            {
                BaseProblemTypePath = "https://dummytest/"
            });

        _controller = new CompanyDetailsController(
            _apiConfigOptionsMock.Object,
            _companyDetailsServiceMock.Object
        );
    }

    [TestMethod]
    public async Task GetOnlineMarketplaceFlag_InvalidRequest_ReturnsBadRequest()
    {
        // Arrange
        // Act
        var result = await _controller.GetOnlineMarketplaceFlag(null);

        // Assert
        result.Should().BeOfType<BadRequestObjectResult>();
        (result as BadRequestObjectResult)!.Value.Should().Be("OrganisationId is invalid");
    }

    [TestMethod]
    public async Task GetOnlineMarketplaceFlag_ValidRequest_NoResult_ReturnsNotFound()
    {
        // Arrange
        var request = new GetOnlineMarketplaceFlagRequest
        {
            OrganisationId = Guid.NewGuid()
        };

        _companyDetailsServiceMock
            .Setup(service => service.GetOnlineMarketplaceFlag(request))
            .ReturnsAsync((GetOnlineMarketplaceFlagResponse)null); // Simulating no result

        // Act
        var result = await _controller.GetOnlineMarketplaceFlag(request);

        // Assert
        result.Should().BeOfType<NotFoundResult>();
    }

    [TestMethod]
    public async Task GetOnlineMarketplaceFlag_ValidRequest_WithResult_ReturnsOk()
    {
        // Arrange
        var organisationId = Guid.NewGuid();
        var request = new GetOnlineMarketplaceFlagRequest
        {
            OrganisationId = organisationId
        };

        var expectedResult = new GetOnlineMarketplaceFlagResponse { IsOnlineMarketPlace = true, OrganisationId = organisationId }; // Mock result

        _companyDetailsServiceMock
            .Setup(service => service.GetOnlineMarketplaceFlag(request))
            .ReturnsAsync(expectedResult);

        // Act
        var result = await _controller.GetOnlineMarketplaceFlag(request);

        // Assert
        result.Should().BeOfType<OkObjectResult>();
        (result as OkObjectResult)!.Value.Should().Be(expectedResult);
    }
}