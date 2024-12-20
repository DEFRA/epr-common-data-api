using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Core.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.UnitTests.Controllers;

[TestClass]
public class CsoMemberDetailsControllerTests
{
    private Mock<ICsoMemberDetailsService> _csoMemberDetailsServiceMock = null!;
    private Mock<IOptions<ApiConfig>> _apiConfigOptionsMock = null!;
    private CsoMemberDetailsController _controller = null!;

    [TestInitialize]
    public void Setup()
    {
        _csoMemberDetailsServiceMock = new Mock<ICsoMemberDetailsService>();
        _apiConfigOptionsMock = new Mock<IOptions<ApiConfig>>();

        _apiConfigOptionsMock
            .Setup(x => x.Value)
            .Returns(new ApiConfig
            {
                BaseProblemTypePath = "https://dummytest/"
            });

        _controller = new CsoMemberDetailsController(
            _apiConfigOptionsMock.Object,
            _csoMemberDetailsServiceMock.Object
        );
    }

    [TestMethod]
    public async Task GetCsoMemberDetails_InvalidRequest_ReturnsBadRequest()
    {
        // Arrange
        // Act
        var result = await _controller.GetCsoMemberDetails(0, Guid.NewGuid());

        // Assert
        result.Should().BeOfType<BadRequestObjectResult>();
        (result as BadRequestObjectResult)!.Value.Should().Be("OrganisationId is invalid");
    }
[TestMethod]
    public async Task GetCsoMemberDetails_InvalidFormatRequest_ReturnsBadRequest()
    {
        // Arrange
        // Act
        var result = await _controller.GetCsoMemberDetails(-1, Guid.Empty);

        // Assert
        result.Should().BeOfType<BadRequestObjectResult>();
        (result as BadRequestObjectResult)!.Value.Should().Be("OrganisationId is invalid");
    }

    [TestMethod]
    public async Task GetCsoMemberDetails_ValidRequest_NoResult_ReturnsNotFound()
    {
        // Arrange
        const int OrganisationId = 1234;
        Guid compSchemeId = Guid.Empty;
        string compScheme = compSchemeId.ToString();
        
        _csoMemberDetailsServiceMock
            .Setup(service => service.GetCsoMemberDetails(OrganisationId,compScheme))
            .ReturnsAsync((GetCsoMemberDetailsResponse[])null!); // Simulating no result

        // Act
        var result = await _controller.GetCsoMemberDetails(OrganisationId, compSchemeId);

        // Assert
        result.Should().BeOfType<NoContentResult>();
    }

    [TestMethod]
    public async Task GetCsoMemberDetails_ValidRequest_WithResult_ReturnsOk()
    {
        // Arrange
        const int OrganisationId = 1234;
        Guid compSchemeId = Guid.Empty;
        string compScheme = compSchemeId.ToString();

        var expectedResult = new [] { new GetCsoMemberDetailsResponse { MemberType = "Large", MemberId = "5678" } }; // Mock result

        _csoMemberDetailsServiceMock
            .Setup(service => service.GetCsoMemberDetails(OrganisationId,compScheme))
            .ReturnsAsync(expectedResult);

        // Act
        var result = await _controller.GetCsoMemberDetails(OrganisationId, compSchemeId);

        // Assert
        result.Should().BeOfType<OkObjectResult>();
        (result as OkObjectResult)!.Value.Should().Be(expectedResult);
    }
}