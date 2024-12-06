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
        const int OrganisationId = 1234;

        var expectedData = new List<CsoMemberDetailsModel>
        {
            new CsoMemberDetailsModel
            {
                MemberId = "5678",
                MemberType = "L",
                IsOnlineMarketplace = true,
                NumberOfSubsidiariesBeingOnlineMarketPlace = 10,
                NumberOfSubsidiaries = 20
            }
        };

        _synapseContextMock
            .ReturnsAsync(expectedData);


        // Act
        var result = await _service.GetCsoMemberDetails(OrganisationId);

        // Assert
        result.Should().NotBeNull();
        result![0].MemberType.Should().Be("Large");
        result[0].MemberId.Should().Be("5678");
        result[0].IsOnlineMarketplace.Should().BeTrue();
        result[0].NumberOfSubsidiariesBeingOnlineMarketPlace.Should().Be(10);
        result[0].NumberOfSubsidiaries.Should().Be(20);

        _synapseContextMock
                Times.Once);

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
                MemberType = "L",
                IsOnlineMarketplace = false,
                NumberOfSubsidiariesBeingOnlineMarketPlace = 10,
                NumberOfSubsidiaries = 20
            }
        };

        _synapseContextMock
            .ReturnsAsync(expectedData);


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
            .ReturnsAsync(emptyData);

        StoredProcedureExtensions.ReturnFakeData = false;

        // Act
        var result = await _service.GetCsoMemberDetails(OrganisationId);

        // Assert
        result.Should().BeNull();
    }

    [TestMethod]
    public async Task GetProducerSize_ExceptionThrown_ReturnsNull()
    {
        // Arrange
        const int OrganisationId = 1234;

        _synapseContextMock
            .ThrowsAsync(new Exception("Database error"));

        StoredProcedureExtensions.ReturnFakeData = false;

        // Act
        var result = await _service.GetCsoMemberDetails(OrganisationId);

        // Assert
        result.Should().BeNull();
    }
}