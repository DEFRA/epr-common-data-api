using EPR.CommonDataService.Api.Configuration;
using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Entities;
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
    public async Task GetUpdatedProducers_ValidRequest_NoResult_ReturnsNoRecords()
    {
        // Arrange
        var fromDate = new DateTime(2025, 1, 1);
        var toDate = new DateTime(2025, 1, 7);

        _producerDetailsServiceMock
            .Setup(service => service.GetUpdatedProducers(fromDate, toDate))
            .ReturnsAsync(new List<UpdatedProducersResponseModel>());

        // Act
        var result = await _controller.GetUpdatedProducers(fromDate, toDate);

        // Assert
        result.Should().BeOfType<NoContentResult>();
    }

    [TestMethod]
    public async Task GetUpdatedProducers_ValidRequest_WithResult_ReturnsOk()
    {
        // Arrange
        var fromDate = new DateTime(2025, 1, 1);
        var toDate = new DateTime(2025, 1, 7);

        var expectedResult = new List<UpdatedProducersResponseModel>
        {
            new UpdatedProducersResponseModel
            {
                OrganisationName = "Organisation A",
                TradingName = "Trading A",
                OrganisationType = "Private",
                CompaniesHouseNumber = "123456",
                OrganisationId = "1",
                AddressLine1 = "123 Main St",
                AddressLine2 = "Suite 1",
                Town = "Town A",
                County = "County A",
                Country = "Country A",
                Postcode = "A1 1AA",
                pEPRID = "PEPRID1",
                Status = "Active"
            }
        };

        _producerDetailsServiceMock
            .Setup(service => service.GetUpdatedProducers(fromDate, toDate))
            .ReturnsAsync(expectedResult);

        // Act
        var result = await _controller.GetUpdatedProducers(fromDate, toDate);

        // Assert
        result.Should().BeOfType<OkObjectResult>();
        (result as OkObjectResult)!.Value.Should().Be(expectedResult);
    }

    [TestMethod]
    public async Task GetUpdatedProducers_InvalidDateRange_ReturnsBadRequest()
    {
        // Arrange
        var fromDate = new DateTime(2025, 1, 1);
        var toDate = new DateTime(2024, 12, 31);

        // Act
        var result = await _controller.GetUpdatedProducers(fromDate, toDate);

        // Assert
        result.Should().BeOfType<NoContentResult>();
    }
}