using EPR.CommonDataService.Core.Extensions;
using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;
using Moq;

namespace EPR.CommonDataService.Core.UnitTests.Services;

[TestClass]
public class CsoMemberDetailsServiceTests
{
    private Mock<SynapseContext> _synapseContextMock = null!;
    private CsoMemberDetailsService _service = null!;

    [TestInitialize]
    public void Setup()
    {
        _synapseContextMock = new Mock<SynapseContext>();
        _service = new CsoMemberDetailsService(_synapseContextMock.Object);
    }

    [TestMethod]
    public async Task GetProducerSize_WhenValidRequestWithData_ReturnsLargeResponse()
    {
        // Arrange
        const int OrganisationId = 123;

        StoredProcedureExtensions.ReturnFakeData = true;

        // Act
        var result = await _service.GetCsoMemberDetails(OrganisationId);

        // Assert
        result.Should().NotBeNull();
        result![0].MemberType.Should().Be("Large");
        result[0].MemberId.Should().Be("5678");
        result[0].IsOnlineMarketplace.Should().BeTrue();
        result[0].NumberOfSubsidiariesBeingOnlineMarketPlace.Should().Be(39);
        result[0].NumberOfSubsidiaries.Should().Be(64);

        _synapseContextMock
            .Verify(ctx => ctx.RunSqlAsync<CsoMemberDetailsModel>(It.IsAny<string>(), It.IsAny<List<SqlParameter>>()),
                Times.Never);

    }

    [TestMethod]
    public async Task GetProducerSize_ValidRequestWithData_ReturnsResponse()
    {
        // Arrange
        const int OrganisationId = 1234;

        var expectedData = new List<CsoMemberDetailsModel>
        {
            new CsoMemberDetailsModel
            {
                MemberId = "5678",
                MemberType = "Large",
                IsOnlineMarketplace = false,
                NumberOfSubsidiariesBeingOnlineMarketPlace = 10,
                NumberOfSubsidiaries = 20
            }
        };

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<CsoMemberDetailsModel>(It.IsAny<string>(), It.IsAny<List<SqlParameter>>()))
            .ReturnsAsync(expectedData);

        StoredProcedureExtensions.ReturnFakeData = false;

        // Act
        var result = await _service.GetCsoMemberDetails(OrganisationId);

        // Assert
        result.Should().NotBeNull();
        result![0].MemberType.Should().Be("Large");
        result[0].MemberId.Should().Be("5678");
        result[0].NumberOfSubsidiariesBeingOnlineMarketPlace.Should().Be(10);
        result[0].NumberOfSubsidiaries.Should().Be(20);
        result[0].IsOnlineMarketplace.Should().BeFalse();
    }

    [TestMethod]
    public async Task GetProducerSize_ValidRequestNoData_ReturnsNull()
    {
        // Arrange
        const int OrganisationId = 1234;

        var emptyData = new List<CsoMemberDetailsModel>();

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<CsoMemberDetailsModel>(It.IsAny<string>(), It.IsAny<List<SqlParameter>>()))
            .ReturnsAsync(emptyData);

        StoredProcedureExtensions.ReturnFakeData = false;

        // Act
        var result = await _service.GetCsoMemberDetails(OrganisationId);

        // Assert
        result.Should().BeEmpty();
    }

    [TestMethod]
    public async Task GetProducerSize_ExceptionThrown_ReturnsNull()
    {
        // Arrange
        const int OrganisationId = 1234;

        _synapseContextMock
            .Setup(ctx => ctx.RunSqlAsync<CsoMemberDetailsModel>(It.IsAny<string>(), It.IsAny<List<SqlParameter>>()))
            .ThrowsAsync(new Exception("Database error"));

        StoredProcedureExtensions.ReturnFakeData = false;

        // Act
        var result = await _service.GetCsoMemberDetails(OrganisationId);

        // Assert
        result.Should().BeNull();
    }
}