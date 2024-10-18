using EPR.CommonDataService.Core.Extensions;
using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;
using Moq;

namespace EPR.CommonDataService.Core.UnitTests.Services;

[TestClass]
public class CompanyDetailsServiceTests
{
    private Mock<SynapseContext> _synapseContextMock = null!;
    private CompanyDetailsService _service = null!;

    [TestInitialize]
    public void Setup()
    {
        _synapseContextMock = new Mock<SynapseContext>();
        _service = new CompanyDetailsService(_synapseContextMock.Object);
    }

    [TestMethod]
    public async Task GetOnlineMarketplaceFlag_WhenValidRequestWithData_ReturnsTrueResponse()
    {
        // Arrange
        var organisationId = Guid.NewGuid();

        StoredProcedureExtensions.ReturnFakeData = true;

        // Act
        var result = await _service.GetOnlineMarketplaceFlag(organisationId);

        // Assert
        result.Should().NotBeNull();
        result!.IsOnlineMarketPlace.Should().BeTrue();
        result.OrganisationId.Should().Be(organisationId);

        _synapseContextMock.Verify(ctx => ctx.RunSqlAsync<CompanyDetailsModel>(It.IsAny<string>(), It.IsAny<List<SqlParameter>>()),
            Times.Never);
    }

    [TestMethod]
    public async Task GetOnlineMarketplaceFlag_WhenReturnFakeDataIsTrue_ReturnsResponse()
    {
        // Arrange
        var organisationId = Guid.NewGuid();

        var expectedData = new List<CompanyDetailsModel>
        {
            new CompanyDetailsModel
            {
                OrganisationId = organisationId,
                IsOnlineMarketplace = true
            }
        };
        StoredProcedureExtensions.ReturnFakeData = false;

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<CompanyDetailsModel>(It.IsAny<string>(), It.IsAny<List<SqlParameter>>()))
            .ReturnsAsync(expectedData);

        // Act
        var result = await _service.GetOnlineMarketplaceFlag(organisationId);

        // Assert
        result.Should().NotBeNull();
        result!.IsOnlineMarketPlace.Should().BeTrue();
        result.OrganisationId.Should().Be(organisationId);
    }

    [TestMethod]
    public async Task GetOnlineMarketplaceFlag_WhenValidRequestNoData_ReturnsNull()
    {
        // Arrange
        var organisationId = Guid.NewGuid();

        var emptyData = new List<CompanyDetailsModel>();

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<CompanyDetailsModel>(It.IsAny<string>(), It.IsAny<List<SqlParameter>>()))
            .ReturnsAsync(emptyData);

        StoredProcedureExtensions.ReturnFakeData = false;

        // Act
        var result = await _service.GetOnlineMarketplaceFlag(organisationId);

        // Assert
        result.Should().BeNull();
    }

    [TestMethod]
    public async Task GetOnlineMarketplaceFlag_WhenExceptionThrown_ReturnsNull()
    {
        // Arrange
        var organisationId = Guid.NewGuid();

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<CompanyDetailsModel>(It.IsAny<string>(), It.IsAny<List<SqlParameter>>()))
            .ThrowsAsync(new Exception("Database error"));

        StoredProcedureExtensions.ReturnFakeData = false;

        // Act
        var result = await _service.GetOnlineMarketplaceFlag(organisationId);

        // Assert
        result.Should().BeNull();
    }
}