using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;
using Moq;

namespace EPR.CommonDataService.Core.UnitTests.Services;

[TestClass]
public class ProducerDetailsServiceTests
{
    private Mock<SynapseContext> _synapseContextMock = null!;
    private ProducerDetailsService _service = null!;

    [TestInitialize]
    public void Setup()
    {
        _synapseContextMock = new Mock<SynapseContext>();
        _service = new ProducerDetailsService(_synapseContextMock.Object);
    }

    [TestMethod]
    public async Task GetProducerSize_WhenValidRequestWithData_ReturnsLargeResponse()
    {
        // Arrange
        const int OrganisationId = 123;
        var expectedData = new List<ProducerDetailsModel>
        {
            new ProducerDetailsModel
            {
                ProducerSize = "L",
                NumberOfSubsidiaries = 54,
                NumberOfSubsidiariesBeingOnlineMarketPlace = 29,
                IsOnlineMarketplace = true
            }
        };
        _synapseContextMock
         .Setup(ctx => ctx.RunSqlAsync<ProducerDetailsModel>(It.IsAny<string>(), It.IsAny<SqlParameter>()))
           .ReturnsAsync(expectedData);

        // Act
        var result = await _service.GetProducerDetails(OrganisationId);

        // Assert
        result.Should().NotBeNull();
        result!.ProducerSize.Should().Be("Large");
        result.NumberOfSubsidiaries.Should().Be(54);
        result.NumberOfSubsidiariesBeingOnlineMarketPlace.Should().Be(29);
        result.IsOnlineMarketplace.Should().BeTrue();

        _synapseContextMock
            .Verify(ctx => ctx.RunSqlAsync<ProducerDetailsModel>(It.IsAny<string>(), It.IsAny<SqlParameter>()),
                Times.Once);

    }

    [TestMethod]
    public async Task GetProducerSize_ValidRequestWithData_ReturnsResponse()
    {
        // Arrange
        const int OrganisationId = 1234;

        var expectedData = new List<ProducerDetailsModel>
        {
            new ProducerDetailsModel
            {
                ProducerSize = "s",
                NumberOfSubsidiaries = 100,
                NumberOfSubsidiariesBeingOnlineMarketPlace = 200,
                IsOnlineMarketplace = false
            }
        };

        _synapseContextMock
             .Setup(ctx => ctx.RunSqlAsync<ProducerDetailsModel>(It.IsAny<string>(), It.IsAny<SqlParameter>()))
            .ReturnsAsync(expectedData);

        // Act
        var result = await _service.GetProducerDetails(OrganisationId);

        // Assert
        result.Should().NotBeNull();
        result!.ProducerSize.Should().Be("Small");
        result.NumberOfSubsidiaries.Should().Be(100);
        result.NumberOfSubsidiariesBeingOnlineMarketPlace.Should().Be(200);
        result.IsOnlineMarketplace.Should().BeFalse();
    }

    [TestMethod]
    public async Task GetProducerSize_ValidRequestNoData_ReturnsNull()
    {
        // Arrange
        const int OrganisationId = 1234;

        var emptyData = new List<ProducerDetailsModel>();

        _synapseContextMock
             .Setup(ctx => ctx.RunSqlAsync<ProducerDetailsModel>(It.IsAny<string>(), It.IsAny<SqlParameter>()))
            .ReturnsAsync(emptyData);

        // Act
        var result = await _service.GetProducerDetails(OrganisationId);

        // Assert
        result.Should().BeNull();
    }

    [TestMethod]
    public async Task GetProducerSize_ExceptionThrown_ReturnsNull()
    {
        // Arrange
        const int OrganisationId = 1234;

        _synapseContextMock
             .Setup(ctx => ctx.RunSqlAsync<ProducerDetailsModel>(It.IsAny<string>(), It.IsAny<SqlParameter>()))
            .ThrowsAsync(new Exception("Database error"));


        // Act
        var result = await _service.GetProducerDetails(OrganisationId);

        // Assert
        result.Should().BeNull();
    }


    [TestMethod]
    public async Task GetProducerDetails_WhenProducerSizeIsInvalid_ReturnsUnknown()
    {
        // Arrange
        const int OrganisationId = 123;
        var expectedData = new List<ProducerDetailsModel>
        {
            new ProducerDetailsModel
            {
                ProducerSize = "X", // Invalid size
                NumberOfSubsidiaries = 10,
                NumberOfSubsidiariesBeingOnlineMarketPlace = 5,
                IsOnlineMarketplace = false
            }
        };
        _synapseContextMock
           .Setup(ctx => ctx.RunSqlAsync<ProducerDetailsModel>(It.IsAny<string>(), It.IsAny<SqlParameter>()))
           .ReturnsAsync(expectedData);

        // Act
        var result = await _service.GetProducerDetails(OrganisationId);

        // Assert
        result.Should().NotBeNull();
        result!.ProducerSize.Should().Be("Unknown"); // Validate fallback to "Unknown"
        result.NumberOfSubsidiaries.Should().Be(10);
        result.NumberOfSubsidiariesBeingOnlineMarketPlace.Should().Be(5);
        result.IsOnlineMarketplace.Should().BeFalse();

        _synapseContextMock
            .Verify(ctx => ctx.RunSqlAsync<ProducerDetailsModel>(It.IsAny<string>(), It.IsAny<SqlParameter>()),
                Times.Once);
    }
}