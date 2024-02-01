using AutoFixture;
using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Core.UnitTests.TestHelpers;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Moq;

namespace EPR.CommonDataService.Core.UnitTests.Services;

[TestClass]
public class SubmissionsServiceTests
{
    private Mock<SynapseContext> _mockSynapseContext = null!;
    private SubmissionsService _sut = null!;
    private IFixture _fixture = null!;

    [TestInitialize]
    public void Setup()
    {
        _fixture = new Fixture();
        _mockSynapseContext = new Mock<SynapseContext>();
        _sut = new SubmissionsService(_mockSynapseContext.Object);
    }

    [TestMethod]
    public async Task GetSubmissionPomSummaries_Calls_Stored_Procedure()
    {
        //arrange
        var request = _fixture
            .Build<SubmissionsSummariesRequest<RegulatorPomDecision>>()
            .With(x => x.PageSize, 10)
            .With(x => x.PageNumber, 2)
            .Create();

        var submissionSummaries = _fixture
            .Build<PomSubmissionSummaryRow>()
            .With(x => x.TotalItems, 100)
            .CreateMany(10).ToList();

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<PomSubmissionSummaryRow>(It.IsAny<string>(), It.IsAny<object[]>()))
            .ReturnsAsync(submissionSummaries);
        
        //Act
        var result = await _sut.GetSubmissionPomSummaries(request);
        
        //Assert
        result.Should().NotBeNull();
        result.PageSize.Should().Be(10);
        result.TotalItems.Should().Be(100);
        result.CurrentPage.Should().Be(2);
    }
    
    [TestMethod]
    public async Task GetSubmissionRegistrationSummaries_Calls_Stored_Procedure()
    {
        //arrange
        var request = _fixture
            .Build<SubmissionsSummariesRequest<RegulatorPomDecision>>()
            .With(x => x.PageSize, 10)
            .With(x => x.PageNumber, 2)
            .Create();

        var submissionSummaries = _fixture
            .Build<RegistrationsSubmissionSummaryRow>()
            .With(x => x.TotalItems, 100)
            .CreateMany(10).ToList();

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<RegistrationsSubmissionSummaryRow>(It.IsAny<string>(), It.IsAny<object[]>()))
            .ReturnsAsync(submissionSummaries);
        
        //Act
        var result = await _sut.GetSubmissionRegistrationSummaries(request);
        
        //Assert
        result.Should().NotBeNull();
        result.PageSize.Should().Be(10);
        result.TotalItems.Should().Be(100);
        result.CurrentPage.Should().Be(2);
    }
}