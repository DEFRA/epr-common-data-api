using EPR.CommonDataService.Core.Models.Requests;
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
    public async Task GetOnlineMarketplaceFlag_ValidRequestWithData_ReturnsResponse()
    {
        // Arrange
        var request = new GetOnlineMarketplaceFlagRequest
        {
            OrganisationId = Guid.NewGuid()
        };

        var expectedData = new List<CompanyDetailsModel>
        {
            new CompanyDetailsModel
            {
                OrganisationId = request.OrganisationId,
                IsOnlineMarketplace = true
            }
        };

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<CompanyDetailsModel>(It.IsAny<string>(), It.IsAny<List<SqlParameter>>()))
            .ReturnsAsync(expectedData);

        // Act
        var result = await _service.GetOnlineMarketplaceFlag(request);

        // Assert
        result.Should().NotBeNull();
        result!.IsOnlineMarketPlace.Should().BeTrue();
        result.OrganisationId.Should().Be(request.OrganisationId);
    }

    [TestMethod]
    public async Task GetOnlineMarketplaceFlag_ValidRequestNoData_ReturnsNull()
    {
        // Arrange
        var request = new GetOnlineMarketplaceFlagRequest
        {
            OrganisationId = Guid.NewGuid()
        };

        var emptyData = new List<CompanyDetailsModel>();

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<CompanyDetailsModel>(It.IsAny<string>(), It.IsAny<List<SqlParameter>>()))
            .ReturnsAsync(emptyData);

        // Act
        var result = await _service.GetOnlineMarketplaceFlag(request);

        // Assert
        result.Should().BeNull();
    }

    [TestMethod]
    public async Task GetOnlineMarketplaceFlag_ExceptionThrown_ReturnsNull()
    {
        // Arrange
        var request = new GetOnlineMarketplaceFlagRequest
        {
            OrganisationId = Guid.NewGuid()
        };

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<CompanyDetailsModel>(It.IsAny<string>(), It.IsAny<List<SqlParameter>>()))
            .ThrowsAsync(new Exception("Database error"));

        // Act
        var result = await _service.GetOnlineMarketplaceFlag(request);

        // Assert
        result.Should().BeNull();
    }
}