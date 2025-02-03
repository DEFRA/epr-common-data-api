using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;
using Moq;

namespace EPR.CommonDataService.Core.UnitTests.Services;

[TestClass]
public class FeeCalculationDetailsServiceTests
{
    private Mock<SynapseContext> _synapseContextMock = null!;
    private FeeCalculationDetailsService _service = null!;

    [TestInitialize]
    public void Setup()
    {
        _synapseContextMock = new Mock<SynapseContext>();
        _service = new FeeCalculationDetailsService(_synapseContextMock.Object);
    }

    [TestMethod]
    public async Task GetProducerSize_WhenValidRequestWithData_ReturnsLargeResponse()
    {
        // Arrange
        var fileId = Guid.NewGuid();
        var expectedData = new List<FeeCalculationDetailsModel>
        {
            new FeeCalculationDetailsModel
            {
                OrganisationSize = "L",
                NumberOfSubsidiaries = 54,
                NumberOfSubsidiariesBeingOnlineMarketPlace = 29,
                IsOnlineMarketplace = true
            }
        };
        _synapseContextMock
         .Setup(ctx => ctx.RunSqlAsync<FeeCalculationDetailsModel>(It.IsAny<string>(), It.IsAny<SqlParameter>()))
           .ReturnsAsync(expectedData);

        // Act
        var result = await _service.GetFeeCalculationDetails(fileId);

        // Assert
        result.Should().NotBeNull();
        result![0].OrganisationSize.Should().Be("Large");
        result[0].NumberOfSubsidiaries.Should().Be(54);
        result[0].NumberOfSubsidiariesBeingOnlineMarketPlace.Should().Be(29);
        result[0].IsOnlineMarketplace.Should().BeTrue();

        _synapseContextMock
            .Verify(ctx => ctx.RunSqlAsync<FeeCalculationDetailsModel>(It.IsAny<string>(), It.IsAny<SqlParameter>()),
                Times.Once);

    }

    [TestMethod]
    public async Task GetProducerSize_ValidRequestWithData_ReturnsResponse()
    {
        // Arrange
        var fileId = Guid.NewGuid();

        var expectedData = new List<FeeCalculationDetailsModel>
        {
            new FeeCalculationDetailsModel
            {
                OrganisationSize = "s",
                NumberOfSubsidiaries = 100,
                NumberOfSubsidiariesBeingOnlineMarketPlace = 200,
                IsOnlineMarketplace = false
            }
        };

        _synapseContextMock
             .Setup(ctx => ctx.RunSqlAsync<FeeCalculationDetailsModel>(It.IsAny<string>(), It.IsAny<SqlParameter>()))
            .ReturnsAsync(expectedData);

        // Act
        var result = await _service.GetFeeCalculationDetails(fileId);

        // Assert
        result.Should().NotBeNull();
        result![0].OrganisationSize.Should().Be("Small");
        result[0].NumberOfSubsidiaries.Should().Be(100);
        result[0].NumberOfSubsidiariesBeingOnlineMarketPlace.Should().Be(200);
        result[0].IsOnlineMarketplace.Should().BeFalse();
    }

    [TestMethod]
    public async Task GetProducerSize_ValidRequestNoData_ReturnsNull()
    {
        // Arrange
        var fileId = Guid.NewGuid();

        var emptyData = new List<FeeCalculationDetailsModel>();

        _synapseContextMock
             .Setup(ctx => ctx.RunSqlAsync<FeeCalculationDetailsModel>(It.IsAny<string>(), It.IsAny<SqlParameter>()))
            .ReturnsAsync(emptyData);

        // Act
        var result = await _service.GetFeeCalculationDetails(fileId);

        // Assert
        result.Should().BeNull();
    }

    [TestMethod]
    public async Task GetProducerSize_ExceptionThrown_ReturnsNull()
    {
        // Arrange
        var fileId = Guid.NewGuid();

        _synapseContextMock
             .Setup(ctx => ctx.RunSqlAsync<FeeCalculationDetailsModel>(It.IsAny<string>(), It.IsAny<SqlParameter>()))
            .ThrowsAsync(new Exception("Database error"));


        // Act
        var result = await _service.GetFeeCalculationDetails(fileId);

        // Assert
        result.Should().BeNull();
    }


    [TestMethod]
    public async Task GetFeeCalculationDetails_WhenProducerSizeIsInvalid_ReturnsUnknown()
    {
        // Arrange
        var fileId = Guid.NewGuid();
        var expectedData = new List<FeeCalculationDetailsModel>
        {
            new FeeCalculationDetailsModel
            {
                OrganisationSize = "X", // Invalid size
                NumberOfSubsidiaries = 10,
                NumberOfSubsidiariesBeingOnlineMarketPlace = 5,
                IsOnlineMarketplace = false
            }
        };
        _synapseContextMock
           .Setup(ctx => ctx.RunSqlAsync<FeeCalculationDetailsModel>(It.IsAny<string>(), It.IsAny<SqlParameter>()))
           .ReturnsAsync(expectedData);

        // Act
        var result = await _service.GetFeeCalculationDetails(fileId);

        // Assert
        result.Should().NotBeNull();
        result![0].OrganisationSize.Should().Be("Unknown"); // Validate fallback to "Unknown"
        result[0].NumberOfSubsidiaries.Should().Be(10);
        result[0].NumberOfSubsidiariesBeingOnlineMarketPlace.Should().Be(5);
        result[0].IsOnlineMarketplace.Should().BeFalse();

        _synapseContextMock
            .Verify(ctx => ctx.RunSqlAsync<FeeCalculationDetailsModel>(It.IsAny<string>(), It.IsAny<SqlParameter>()),
                Times.Once);
    }
}