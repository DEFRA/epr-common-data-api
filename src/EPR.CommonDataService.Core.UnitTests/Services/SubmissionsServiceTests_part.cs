using AutoFixture;
using EPR.CommonDataService.Core.Models.Response;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;
using Moq;

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
    public async Task GetOrganisationRegistrationSubmissionDetailsPartAsync_Calls_Stored_Procedure()
    {
        //Arrange
        var paycalParametersResponse = _fixture
            .Build<SubmissionDetailsResponse>()
            .CreateMany(1).ToList();

        _mockSynapseContext
            .Setup(x => x.RunSpCommandAsync<SubmissionDetailsResponse>(It.IsAny<string>(), It.IsAny<ILogger>(), It.IsAny<string>(), It.IsAny<SqlParameter[]>()))
            .ReturnsAsync(paycalParametersResponse);

        //Act
        var result = await _sut.GetOrganisationRegistrationSubmissionDetailsPartAsync(Guid.NewGuid());

        //Assert
        result.Should().NotBeNull();
        result.As<SubmissionDetailsResponse>().Should().NotBeNull();
    }
}