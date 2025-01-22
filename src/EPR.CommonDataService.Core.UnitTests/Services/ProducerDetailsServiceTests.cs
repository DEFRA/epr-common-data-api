using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;
using Moq;

namespace EPR.CommonDataService.Core.UnitTests.Services;

[TestClass]
public class ProducerDetailsServiceTests
{
    private Mock<SynapseContext> _synapseContextMock = null!;
    private ProducerDetailsService _service = null!;
    private Mock<ILogger<ProducerDetailsService>> _mockLogger = null!;

    [TestInitialize]
    public void Setup()
    {
        _synapseContextMock = new Mock<SynapseContext>();
        _mockLogger = new Mock<ILogger<ProducerDetailsService>>();
        _service = new ProducerDetailsService(_synapseContextMock.Object, _mockLogger.Object);
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

    [TestMethod]
    public async Task GetUpdatedProducers_ValidRequestWithData_ReturnsUpdatedProducers()
    {
        // Arrange
        var fromDate = new DateTime(2025, 1, 1);
        var toDate = new DateTime(2025, 1, 7);

        var expectedData = new List<UpdatedProducersResponseModel>
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
                Status = "CS Deleted"
            },
            new UpdatedProducersResponseModel
            {
                OrganisationName = "Organisation B",
                TradingName = "Trading B",
                OrganisationType = "Public",
                CompaniesHouseNumber = "654321",
                OrganisationId = "2",
                AddressLine1 = "456 High St",
                AddressLine2 = "Floor 2",
                Town = "Town B",
                County = "County B",
                Country = "Country B",
                Postcode = "B2 2BB",
                pEPRID = "PEPRID2",
                Status = "DR Moved to CS"
            }
        };

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<UpdatedProducersResponseModel>(It.IsAny<string>(), It.IsAny<SqlParameter[]>()))
            .ReturnsAsync(expectedData);

        // Act
        var result = await _service.GetUpdatedProducers(fromDate, toDate);

        // Assert
        result.Should().NotBeNull();
        result.Count.Should().Be(2);

        var firstProducer = result[0];
        firstProducer.OrganisationName.Should().Be("Organisation A");
        firstProducer.TradingName.Should().Be("Trading A");
        firstProducer.OrganisationType.Should().Be("Private");
        firstProducer.CompaniesHouseNumber.Should().Be("123456");
        firstProducer.OrganisationId.Should().Be("1");
        firstProducer.AddressLine1.Should().Be("123 Main St");
        firstProducer.AddressLine2.Should().Be("Suite 1");
        firstProducer.Town.Should().Be("Town A");
        firstProducer.County.Should().Be("County A");
        firstProducer.Country.Should().Be("Country A");
        firstProducer.Postcode.Should().Be("A1 1AA");
        firstProducer.pEPRID.Should().Be("PEPRID1");
        firstProducer.Status.Should().Be("CS Deleted");

        var secondProducer = result[1];
        secondProducer.OrganisationName.Should().Be("Organisation B");
        secondProducer.TradingName.Should().Be("Trading B");
        secondProducer.OrganisationType.Should().Be("Public");
        secondProducer.CompaniesHouseNumber.Should().Be("654321");
        secondProducer.OrganisationId.Should().Be("2");
        secondProducer.AddressLine1.Should().Be("456 High St");
        secondProducer.AddressLine2.Should().Be("Floor 2");
        secondProducer.Town.Should().Be("Town B");
        secondProducer.County.Should().Be("County B");
        secondProducer.Country.Should().Be("Country B");
        secondProducer.Postcode.Should().Be("B2 2BB");
        secondProducer.pEPRID.Should().Be("PEPRID2");
        secondProducer.Status.Should().Be("DR Moved to CS");

        _synapseContextMock
            .Verify(ctx => ctx.RunSqlAsync<UpdatedProducersResponseModel>(It.IsAny<string>(), It.IsAny<SqlParameter[]>()),
                    Times.Once);
    }

    [TestMethod]
    public async Task GetUpdatedProducers_ValidRequestNoData_ReturnsEmptyList()
    {
        // Arrange
        var fromDate = new DateTime(2025, 1, 1);
        var toDate = new DateTime(2025, 1, 7);

        var emptyData = new List<UpdatedProducersResponseModel>();

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<UpdatedProducersResponseModel>(It.IsAny<string>(), It.IsAny<SqlParameter[]>()))
            .ReturnsAsync(emptyData);

        // Act
        var result = await _service.GetUpdatedProducers(fromDate, toDate);

        // Assert
        result.Should().NotBeNull();
        result.Count.Should().Be(0);

        _synapseContextMock
            .Verify(ctx => ctx.RunSqlAsync<UpdatedProducersResponseModel>(It.IsAny<string>(), It.IsAny<SqlParameter[]>()),
                    Times.Once);
    }

    [TestMethod]
    public async Task GetUpdatedProducers_ExceptionThrown_ReturnsEmptyList()
    {
        // Arrange
        var fromDate = new DateTime(2025, 1, 1);
        var toDate = new DateTime(2025, 1, 7);

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<UpdatedProducersResponseModel>(It.IsAny<string>(), It.IsAny<SqlParameter[]>()))
            .ThrowsAsync(new Exception("Database error"));

        // Act
        var result = await _service.GetUpdatedProducers(fromDate, toDate);

        // Assert
        result.Should().NotBeNull();
        result.Count.Should().Be(0);
    }

    [TestMethod]
    public async Task GetUpdatedProducers_ValidRequestWithNoRecordsFound_ReturnsEmptyList()
    {
        // Arrange
        var fromDate = new DateTime(2025, 1, 1);
        var toDate = new DateTime(2025, 1, 7);

        var emptyData = new List<UpdatedProducersResponseModel>();

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<UpdatedProducersResponseModel>(It.IsAny<string>(), It.IsAny<SqlParameter[]>()))
            .ReturnsAsync(emptyData);

        // Act
        var result = await _service.GetUpdatedProducers(fromDate, toDate);

        // Assert
        result.Should().BeEmpty();
    }

    [TestMethod]
    public async Task GetUpdatedProducers_InvalidDateRange_ReturnsEmptyList()
    {
        // Arrange
        var fromDate = new DateTime(2025, 1, 10);
        var toDate = new DateTime(2025, 1, 5);

        var emptyData = new List<UpdatedProducersResponseModel>();

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<UpdatedProducersResponseModel>(It.IsAny<string>(), It.IsAny<SqlParameter[]>()))
            .ReturnsAsync(emptyData);

        // Act
        var result = await _service.GetUpdatedProducers(fromDate, toDate);

        // Assert
        result.Should().NotBeNull();
        result.Count.Should().Be(0);
    }

    [TestMethod]
    public async Task GetUpdatedProducers_NoUpdatesInDateRange_ReturnsEmptyList()
    {
        // Arrange
        var fromDate = new DateTime(2025, 1, 1);
        var toDate = new DateTime(2025, 1, 7);

        var emptyData = new List<UpdatedProducersResponseModel>();

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<UpdatedProducersResponseModel>(It.IsAny<string>(), It.IsAny<SqlParameter[]>()))
            .ReturnsAsync(emptyData);

        // Act
        var result = await _service.GetUpdatedProducers(fromDate, toDate);

        // Assert
        result.Should().NotBeNull();
        result.Count.Should().Be(0);
    }
}