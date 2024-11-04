using AutoFixture;
using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Moq;
using System.Data;

namespace EPR.CommonDataService.Core.UnitTests.Services;

[TestClass]
public class SubmissionsServiceTests
{
    private Mock<SynapseContext> _mockSynapseContext = null!;
    private SubmissionsService _sut = null!;
    private Fixture _fixture = null!;
    private Mock<IDatabaseTimeoutService> _databaseTimeoutService = null!;

    [TestInitialize]
    public void Setup()
    {
        _fixture = new Fixture();
        _mockSynapseContext = new Mock<SynapseContext>();
        _databaseTimeoutService = new Mock<IDatabaseTimeoutService>();
        _sut = new SubmissionsService(_mockSynapseContext.Object, _databaseTimeoutService.Object);
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
    public async Task GetSubmissionPomSummaries_returns_itemsCount_Of_Zero_when_Response_IsEmpty()
    {
        //arrange
        var request = _fixture
            .Build<SubmissionsSummariesRequest<RegulatorPomDecision>>()
            .With(x => x.PageSize, 10)
            .With(x => x.PageNumber, 2)
            .Create();

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<PomSubmissionSummaryRow>(It.IsAny<string>(), It.IsAny<object[]>()))
            .ReturnsAsync(Array.Empty<PomSubmissionSummaryRow>());

        //Act
        var result = await _sut.GetSubmissionPomSummaries(request);

        //Assert
        result.Should().NotBeNull();
        result.TotalItems.Should().Be(0);
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

    [TestMethod]
    public async Task GetApprovedSubmissionsWithAggregatedPomData_WhenApprovedSubmissionsExist_ReturnsThem()
    {
        // Arrange
        var expectedResult = _fixture
            .Build<ApprovedSubmissionEntity>()
            .CreateMany(10).ToList();

        var approvedAfter = DateTime.UtcNow;
        var periods = "2024-P1,2024-P2";

        var sqlParameters = Array.Empty<object>();

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<ApprovedSubmissionEntity>(It.IsAny<string>(), It.IsAny<object[]>()))
            .Callback<string, object[]>((_, o) => sqlParameters = o)
            .ReturnsAsync(expectedResult);

        _databaseTimeoutService
            .Setup(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()))
            .Verifiable();

        // Act 
        var result = await _sut.GetApprovedSubmissionsWithAggregatedPomData(approvedAfter, periods);

        // Assert
        result.Should().NotBeNull();
        result.Count.Should().Be(10);
        sqlParameters.Should().BeEquivalentTo(new object[]
        {
            new SqlParameter("@ApprovedAfter", SqlDbType.DateTime2) { Value = approvedAfter },
            new SqlParameter("@Periods", SqlDbType.VarChar) { Value = periods }
        });
        _databaseTimeoutService.Verify(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()), Times.Once);
    }

    [TestMethod]
    public async Task GetApprovedSubmissionsWithAggregatedPomData_WhenApprovedSubmissionsDoNotExist_ReturnsEmpty()
    {
        // Arrange
        var approvedAfter = DateTime.UtcNow;
        var periods = "2024-P1,2024-P2";

        var sqlParameters = Array.Empty<object>();

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<ApprovedSubmissionEntity>(It.IsAny<string>(), It.IsAny<object[]>()))
            .Callback<string, object[]>((_, o) => sqlParameters = o)
            .ReturnsAsync(Array.Empty<ApprovedSubmissionEntity>());

        _databaseTimeoutService
            .Setup(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()))
            .Verifiable();

        // Act 
        var result = await _sut.GetApprovedSubmissionsWithAggregatedPomData(approvedAfter, periods);

        // Assert
        result.Should().NotBeNull();
        result.Count.Should().Be(0);
        sqlParameters.Should().BeEquivalentTo(new object[]
        {
            new SqlParameter("@ApprovedAfter", SqlDbType.DateTime2) { Value = approvedAfter },
            new SqlParameter("@Periods", SqlDbType.VarChar) { Value = periods }
        });
        _databaseTimeoutService.Verify(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()), Times.Once);
    }

    [TestMethod]
    [ExpectedException(typeof(DataException))]
    public async Task GetApprovedSubmissionsWithAggregatedPomData_WhenExceptionOccurs_ShouldThrowDataException()
    {
        // Arrange
        var approvedAfter = DateTime.UtcNow;
        var periods = "2024-P1,2024-P2";

        // Set up the mock to throw a generic exception when RunSqlAsync is called
        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<ApprovedSubmissionEntity>(It.IsAny<string>(), It.IsAny<object[]>()))
            .ThrowsAsync(new Exception("Simulated exception"));

        _databaseTimeoutService
            .Setup(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()))
            .Verifiable();

        // Act
        await _sut.GetApprovedSubmissionsWithAggregatedPomData(approvedAfter, periods);

        // Assert - This will be handled by the ExpectedException attribute
        _databaseTimeoutService.Verify(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()), Times.Once);
    }

    [TestMethod]
    public async Task GetApprovedSubmissionsWithAggregatedPomData_WhenPeriodsIsNull_ExecutesWithNullParameter()
    {
        // Arrange
        var expectedResult = _fixture.Build<ApprovedSubmissionEntity>().CreateMany(5).ToList();
        var approvedAfter = DateTime.UtcNow;
        string periods = null; // Null periods

        var sqlParameters = Array.Empty<object>();

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<ApprovedSubmissionEntity>(It.IsAny<string>(), It.IsAny<object[]>()))
            .Callback<string, object[]>((_, o) => sqlParameters = o)
            .ReturnsAsync(expectedResult);

        _databaseTimeoutService
            .Setup(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()))
            .Verifiable();

        // Act 
        var result = await _sut.GetApprovedSubmissionsWithAggregatedPomData(approvedAfter, periods);

        // Assert
        result.Should().NotBeNull();
        result.Count.Should().Be(5);
        sqlParameters.Should().BeEquivalentTo(new object[]
        {
        new SqlParameter("@ApprovedAfter", SqlDbType.DateTime2) { Value = approvedAfter },
        new SqlParameter("@Periods", SqlDbType.VarChar) { Value = DBNull.Value } // Check for DBNull when periods is null
        });
        _databaseTimeoutService.Verify(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()), Times.Once);
    }

    [TestMethod]
    public async Task GetApprovedSubmissionsWithAggregatedPomData_WhenPeriodsIsEmpty_ExecutesWithEmptyParameter()
    {
        // Arrange
        var expectedResult = _fixture.Build<ApprovedSubmissionEntity>().CreateMany(3).ToList();
        var approvedAfter = DateTime.UtcNow;
        var periods = ""; // Empty periods

        var sqlParameters = Array.Empty<object>();

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<ApprovedSubmissionEntity>(It.IsAny<string>(), It.IsAny<object[]>()))
            .Callback<string, object[]>((_, o) => sqlParameters = o)
            .ReturnsAsync(expectedResult);

        _databaseTimeoutService
            .Setup(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()))
            .Verifiable();

        // Act 
        var result = await _sut.GetApprovedSubmissionsWithAggregatedPomData(approvedAfter, periods);

        // Assert
        result.Should().NotBeNull();
        result.Count.Should().Be(3);
        sqlParameters.Should().BeEquivalentTo(new object[]
        {
        new SqlParameter("@ApprovedAfter", SqlDbType.DateTime2) { Value = approvedAfter },
        new SqlParameter("@Periods", SqlDbType.VarChar) { Value = periods } // Check for empty string when periods is empty
        });
        _databaseTimeoutService.Verify(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()), Times.Once);
    }
}