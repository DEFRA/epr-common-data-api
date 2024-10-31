using EPR.CommonDataService.Core.Extensions;
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

        StoredProcedureExtensions.ReturnFakeData = true;

        // Act
        var result = await _service.GetProducerDetails(OrganisationId);

        // Assert
        result.Should().NotBeNull();
        result!.ProducerSize.Should().Be("Large");
        result.OrganisationId.Should().Be(OrganisationId);

        _synapseContextMock
            .Verify(ctx => ctx.RunSqlAsync<ProducerDetailsModel>(It.IsAny<string>(), It.IsAny<List<SqlParameter>>()),
                Times.Never);

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
                OrganisationId = OrganisationId,
                ProducerSize = "Large"
            }
        };

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<ProducerDetailsModel>(It.IsAny<string>(), It.IsAny<List<SqlParameter>>()))
            .ReturnsAsync(expectedData);

        StoredProcedureExtensions.ReturnFakeData = false;

        // Act
        var result = await _service.GetProducerDetails(OrganisationId);

        // Assert
        result.Should().NotBeNull();
        result!.ProducerSize.Should().Be("Large");
        result.OrganisationId.Should().Be(OrganisationId);
    }

    [TestMethod]
    public async Task GetProducerSize_ValidRequestNoData_ReturnsNull()
    {
        // Arrange
        const int OrganisationId = 1234;

        var emptyData = new List<ProducerDetailsModel>();

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<ProducerDetailsModel>(It.IsAny<string>(), It.IsAny<List<SqlParameter>>()))
            .ReturnsAsync(emptyData);

        StoredProcedureExtensions.ReturnFakeData = false;

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
            .Setup(ctx => ctx.RunSqlAsync<ProducerDetailsModel>(It.IsAny<string>(), It.IsAny<List<SqlParameter>>()))
            .ThrowsAsync(new Exception("Database error"));

        StoredProcedureExtensions.ReturnFakeData = false;

        // Act
        var result = await _service.GetProducerDetails(OrganisationId);

        // Assert
        result.Should().BeNull();
    }
}