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
    public async Task GetProducerPaycalParametersAsync_Calls_Stored_Procedure()
    {
        //Arrange
        var producerPaycalParametersResponse = _fixture
            .Build<ProducerPaycalParametersResponse>()
            .CreateMany(1).ToList();

        _mockSynapseContext
            .Setup(x => x.RunSpCommandAsync<ProducerPaycalParametersResponse>(It.IsAny<string>(), It.IsAny<ILogger>(), It.IsAny<string>(), It.IsAny<SqlParameter[]>()))
            .ReturnsAsync(producerPaycalParametersResponse);

        //Act
        var result = await _sut.GetProducerPaycalParametersAsync(Guid.NewGuid(), false, Guid.Empty);

        //Assert
        result.Should().NotBeNull();
        result.As<ProducerPaycalParametersResponse>().Should().NotBeNull();
    }

    [TestMethod]
    public async Task GetProducerPaycalParametersAsync_ThrowsTimeoutException()
    {
        // Arrange
        _mockSynapseContext
            .Setup(db => db.RunSpCommandAsync<ProducerPaycalParametersResponse>(
                It.IsAny<string>(),
                It.IsAny<ILogger>(),
                It.IsAny<string>(),
                It.IsAny<SqlParameter[]>()))
            .ThrowsAsync(BuildSqlException(-2));

        // Act & Assert
        await Assert.ThrowsExceptionAsync<TimeoutException>(() => _sut.GetProducerPaycalParametersAsync(Guid.NewGuid(), false, Guid.Empty));
    }

    [TestMethod]
    public async Task GetProducerPaycalParametersAsync_ThrowsException()
    {
        // Arrange
        _mockSynapseContext
            .Setup(db => db.RunSpCommandAsync<ProducerPaycalParametersResponse>(
                It.IsAny<string>(),
                It.IsAny<ILogger>(),
                It.IsAny<string>(),
                It.IsAny<SqlParameter[]>()))
            .ThrowsAsync(BuildSqlException(-1));

        // Act & Assert
        await Assert.ThrowsExceptionAsync<DataException>(() => _sut.GetProducerPaycalParametersAsync(Guid.NewGuid(), false, Guid.Empty));
    }

    [TestMethod]
    public async Task GetCsoPaycalParametersAsync_Calls_Stored_Procedure()
    {
        //Arrange
        var csoPaycalParametersResponse = _fixture
            .Build<CsoPaycalParametersResponse>()
            .CreateMany(10).ToList();

        _mockSynapseContext
            .Setup(x => x.RunSpCommandAsync<CsoPaycalParametersResponse>(It.IsAny<string>(), It.IsAny<ILogger>(), It.IsAny<string>(), It.IsAny<SqlParameter[]>()))
            .ReturnsAsync(csoPaycalParametersResponse);

        //Act
        var result = await _sut.GetCsoPaycalParametersAsync(Guid.NewGuid(), false, Guid.Empty);

        //Assert
        result.Should().NotBeNull();
        result.As<IList<CsoPaycalParametersResponse>>().Count.Should().Be(10);
    }

    [TestMethod]
    public async Task GetCsoPaycalParametersAsync_ThrowsTimeoutException()
    {
        // Arrange
        _mockSynapseContext
            .Setup(db => db.RunSpCommandAsync<CsoPaycalParametersResponse>(
                It.IsAny<string>(),
                It.IsAny<ILogger>(),
                It.IsAny<string>(),
                It.IsAny<SqlParameter[]>()))
            .ThrowsAsync(BuildSqlException(-2));

        // Act & Assert
        await Assert.ThrowsExceptionAsync<TimeoutException>(() => _sut.GetCsoPaycalParametersAsync(Guid.NewGuid(), false, Guid.Empty));
    }

    [TestMethod]
    public async Task GetCsoPaycalParametersAsync_ThrowsException()
    {
        // Arrange
        _mockSynapseContext
            .Setup(db => db.RunSpCommandAsync<CsoPaycalParametersResponse>(
                It.IsAny<string>(),
                It.IsAny<ILogger>(),
                It.IsAny<string>(),
                It.IsAny<SqlParameter[]>()))
            .ThrowsAsync(BuildSqlException(-1));

        // Act & Assert
        await Assert.ThrowsExceptionAsync<DataException>(() => _sut.GetCsoPaycalParametersAsync(Guid.NewGuid(), false, Guid.Empty));
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