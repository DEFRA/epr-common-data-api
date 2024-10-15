using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;
using Moq;

namespace EPR.CommonDataService.Core.UnitTests.Services;

[TestClass]
public class ProducerPropertiesServiceTests
{
    private Mock<SynapseContext> _synapseContextMock = null!;
    private ProducerPropertiesService _service = null!;

    [TestInitialize]
    public void Setup()
    {
        _synapseContextMock = new Mock<SynapseContext>();
        _service = new ProducerPropertiesService(_synapseContextMock.Object);
    }

    [TestMethod]
    public async Task GetProducerSize_ValidRequestWithData_ReturnsResponse()
    {
        // Arrange
        var organisationId = Guid.NewGuid();

        var expectedData = new List<ProducerPropertiesModel>
        {
            new ProducerPropertiesModel
            {
                OrganisationId = organisationId,
                ProducerSize = "Large"
            }
        };

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<ProducerPropertiesModel>(It.IsAny<string>(), It.IsAny<List<SqlParameter>>()))
            .ReturnsAsync(expectedData);

        // Act
        var result = await _service.GetProducerSize(organisationId);

        // Assert
        result.Should().NotBeNull();
        result!.ProducerSize.Should().Be("Large");
        result.OrganisationId.Should().Be(organisationId);
    }

    [TestMethod]
    public async Task GetProducerSize_ValidRequestNoData_ReturnsNull()
    {
        // Arrange
        var organisationId = Guid.NewGuid();

        var emptyData = new List<ProducerPropertiesModel>();

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<ProducerPropertiesModel>(It.IsAny<string>(), It.IsAny<List<SqlParameter>>()))
            .ReturnsAsync(emptyData);

        // Act
        var result = await _service.GetProducerSize(organisationId);

        // Assert
        result.Should().BeNull();
    }

    [TestMethod]
    public async Task GetProducerSize_ExceptionThrown_ReturnsNull()
    {
        // Arrange
        var organisationId = Guid.NewGuid();

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<ProducerPropertiesModel>(It.IsAny<string>(), It.IsAny<List<SqlParameter>>()))
            .ThrowsAsync(new Exception("Database error"));

        // Act
        var result = await _service.GetProducerSize(organisationId);

        // Assert
        result.Should().BeNull();
    }
}