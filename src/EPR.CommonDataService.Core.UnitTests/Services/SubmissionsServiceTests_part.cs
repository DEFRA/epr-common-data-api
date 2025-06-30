using AutoFixture;
using EPR.CommonDataService.Core.Models.Response;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;
using Moq;
using System.Data;

namespace EPR.CommonDataService.Core.UnitTests.Services;

public partial class SubmissionsServiceTests
{
    [TestMethod]
    public async Task GetPaycalParametersAsync_Calls_Stored_Procedure()
    {
        //Arrange
        var paycalParametersResponse = _fixture
            .Build<PaycalParametersResponse>()
            .CreateMany(10).ToList();

        _mockSynapseContext
            .Setup(x => x.RunSpCommandAsync<PaycalParametersResponse>(It.IsAny<string>(), It.IsAny<ILogger>(), It.IsAny<string>(), It.IsAny<SqlParameter[]>()))
            .ReturnsAsync(paycalParametersResponse);

        //Act
        var result = await _sut.GetPaycalParametersAsync(Guid.NewGuid());

        //Assert
        result.Should().NotBeNull();
        result.As<IList<PaycalParametersResponse>>().Count.Should().Be(10);
    }

    [TestMethod]
    public async Task GetPaycalParametersAsync_ThrowsTimeoutException()
    {
        // Arrange
        _mockSynapseContext
            .Setup(db => db.RunSpCommandAsync<PaycalParametersResponse>(
                It.IsAny<string>(),
                It.IsAny<ILogger>(),
                It.IsAny<string>(),
                It.IsAny<SqlParameter[]>()))
            .ThrowsAsync(BuildSqlException(-2));

        // Act & Assert
        await Assert.ThrowsExceptionAsync<TimeoutException>(() => _sut.GetPaycalParametersAsync(Guid.NewGuid()));
    }

    [TestMethod]
    public async Task GetPaycalParametersAsync_ThrowsException()
    {
        // Arrange
        _mockSynapseContext
            .Setup(db => db.RunSpCommandAsync<PaycalParametersResponse>(
                It.IsAny<string>(),
                It.IsAny<ILogger>(),
                It.IsAny<string>(),
                It.IsAny<SqlParameter[]>()))
            .ThrowsAsync(BuildSqlException(-1));

        // Act & Assert
        await Assert.ThrowsExceptionAsync<DataException>(() => _sut.GetPaycalParametersAsync(Guid.NewGuid()));
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissionDetailsAsync_Calls_Stored_Procedure()
    {
        //Arrange
        var paycalParametersResponse = _fixture
            .Build<OrganisationRegistrationSubmissionDetailsResponse>()
            .CreateMany(1).ToList();

        _mockSynapseContext
            .Setup(x => x.RunSpCommandAsync<OrganisationRegistrationSubmissionDetailsResponse>(It.IsAny<string>(), It.IsAny<ILogger>(), It.IsAny<string>(), It.IsAny<SqlParameter[]>()))
            .ReturnsAsync(paycalParametersResponse);

        //Act
        var result = await _sut.GetOrganisationRegistrationSubmissionDetailsAsync(Guid.NewGuid());

        //Assert
        result.Should().NotBeNull();
        result.As<OrganisationRegistrationSubmissionDetailsResponse>().Should().NotBeNull();
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissionDetailsAsync_ThrowsTimeoutException()
    {
        // Arrange
        _mockSynapseContext
            .Setup(db => db.RunSpCommandAsync<OrganisationRegistrationSubmissionDetailsResponse>(
                It.IsAny<string>(),
                It.IsAny<ILogger>(),
                It.IsAny<string>(),
                It.IsAny<SqlParameter[]>()))
            .ThrowsAsync(BuildSqlException(-2));

        // Act & Assert
        await Assert.ThrowsExceptionAsync<TimeoutException>(() => _sut.GetOrganisationRegistrationSubmissionDetailsAsync(Guid.NewGuid()));
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissionDetailsAsync_ThrowsException()
    {
        // Arrange
        _mockSynapseContext
            .Setup(db => db.RunSpCommandAsync<OrganisationRegistrationSubmissionDetailsResponse>(
                It.IsAny<string>(),
                It.IsAny<ILogger>(),
                It.IsAny<string>(),
                It.IsAny<SqlParameter[]>()))
            .ThrowsAsync(BuildSqlException(-1));

        // Act & Assert
        await Assert.ThrowsExceptionAsync<DataException>(() => _sut.GetOrganisationRegistrationSubmissionDetailsAsync(Guid.NewGuid()));
    }
}