using AutoFixture;
using EPR.CommonDataService.Core.Models;
using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Core.UnitTests.TestHelpers;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Logging;
using Moq;

namespace EPR.CommonDataService.Core.UnitTests.Services;

[TestClass]
public class SubmissionEventServiceTests
{
    private SubmissionEventService _sut = null!;

    private Fixture _fixture = null!;
    private Mock<SynapseContext> _mockSynapseContext = null!;

    [TestInitialize]
    public void Setup()
    {
        var mockLogger = new Mock<ILogger<SubmissionsService>>();
        _fixture = new Fixture();
        _mockSynapseContext = new Mock<SynapseContext>();

        _sut = new SubmissionEventService(_mockSynapseContext.Object, mockLogger.Object);
    }

    [TestMethod]
    public async Task When_Last_Sync_Time_Is_Requested_Then_Return_Date_Time()
    {
        var lastSyncExpected = _fixture
            .Build<SubmissionEventsLastSync>()
            .With(x => x.LastSyncTime, DateTime.UtcNow.AddHours(-1))
            .CreateMany(1).ToList();

        _mockSynapseContext
            .Setup(x => x.RunSpCommandAsync<SubmissionEventsLastSync>(
                It.IsAny<string>(),
                It.IsAny<ILogger>(),
                It.IsAny<string>(),
                It.IsAny<SqlParameter[]>()
            ))
            .ReturnsAsync(lastSyncExpected).Verifiable();

        //Act
        var result = await _sut.GetLastSyncTimeAsync();

        //Assert
        result.Should().NotBeNull();
        result.Should().BeOfType<SubmissionEventsLastSync>();
    }

    [TestMethod]
    public async Task When_Last_Sync_Time_Returns_No_Data_Throws_Exception()
    {
        var lastSyncExpected = _fixture
            .Build<SubmissionEventsLastSync>()
            .With(x => x.LastSyncTime, DateTime.UtcNow.AddHours(-1))
            .CreateMany(0).ToList();

        _mockSynapseContext
            .Setup(x => x.RunSpCommandAsync<SubmissionEventsLastSync>(
                It.IsAny<string>(),
                It.IsAny<ILogger>(),
                It.IsAny<string>(),
                It.IsAny<SqlParameter[]>()
            ))
            .ReturnsAsync(lastSyncExpected).Verifiable();

        //Act
        var ex = await Assert.ThrowsExceptionAsync<Exception>(async () =>
        {
            await _sut.GetLastSyncTimeAsync();
        });

        //Assert
        StringAssert.Contains(ex.Message, "No data found from GetLastSyncTime");
    }
}