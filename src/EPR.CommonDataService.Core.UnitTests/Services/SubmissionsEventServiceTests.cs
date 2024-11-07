using EPR.CommonDataService.Core.Models;
using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Core.UnitTests.TestHelpers;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace EPR.CommonDataService.Core.UnitTests.Services;

[TestClass]
public class SubmissionEventServiceTests
{
    private SynapseContext _synapseContext = null!;
    private SubmissionEventService _sut = null!;

    private DbContextOptions<SynapseContext> _dbContextOptions = null!;

    [TestInitialize]
    public void Setup()
    {
        _dbContextOptions = new DbContextOptionsBuilder<SynapseContext>()
            .UseInMemoryDatabase("SynapseTests")
            .ConfigureWarnings(builder => builder.Ignore(InMemoryEventId.TransactionIgnoredWarning))
            .Options;
        _synapseContext = new SynapseContext(_dbContextOptions);
        SubmissionEventTestHelper.SetupDatabaseForSubmissionEvents(_synapseContext);

        _sut = new SubmissionEventService(_synapseContext);
    }

    [TestMethod]
    public async Task When_Last_Sync_Time_Is_Requested_Then_Return_Date_Time()
    {
        //Act
        var result = await _sut.GetLastSyncTimeAsync();

        //Assert
        result.Should().NotBeNull();
        result.Should().BeOfType<SubmissionEventsLastSync>();
    }
}