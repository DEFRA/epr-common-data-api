using AutoFixture;
using EPR.CommonDataService.Core.Models;
using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Core.Services;
using EPR.CommonDataService.Data.Entities;
using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using System.Data;
using System.Diagnostics.CodeAnalysis;
using System.Reflection;

namespace EPR.CommonDataService.Core.UnitTests.Services;

[ExcludeFromCodeCoverage]
[TestClass]
public class SubmissionsServiceTests
{
    private Mock<SynapseContext> _mockSynapseContext = null!;
    private SubmissionsService _sut = null!;
    private Fixture _fixture = null!;
    private Mock<IDatabaseTimeoutService> _databaseTimeoutService = null!;
    private Mock<IDbContextFactory<SynapseContext>> _mockDbFactory = null!;

    [TestInitialize]
    public void Setup()
    {
        _fixture = new Fixture();
        _mockSynapseContext = new Mock<SynapseContext>();
        _databaseTimeoutService = new Mock<IDatabaseTimeoutService>();

        var mockLogger = new Mock<ILogger<SubmissionsService>>();
        var configurationMock = new Mock<IConfiguration>();
        configurationMock.Setup(c => c["LogPrefix"]).Returns("[EPR.CommonDataService]");

        _mockDbFactory = new Mock<IDbContextFactory<SynapseContext>>();
        
        _mockDbFactory.Setup(c => c.CreateDbContext()).Returns(_mockSynapseContext.Object);
        _mockDbFactory
            .Setup(f => f.CreateDbContextAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(_mockSynapseContext.Object);
        _mockDbFactory
            .Setup(f => f.CreateDbContextAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(_mockSynapseContext.Object);

        _sut = new SubmissionsService(_mockDbFactory.Object, /*_mockSynapseContext.Object, */_databaseTimeoutService.Object, mockLogger.Object, configurationMock.Object);
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
        var includePackagingTypes = "HH,NH,PB,HDC,NHC";
        var includePackagingMaterials = "AL,FC,GL,PC,PL,ST,WD";
        var includeOrganisationSize = "L";

        var sqlParameters = Array.Empty<object>();

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<ApprovedSubmissionEntity>(It.IsAny<string>(), It.IsAny<object[]>()))
            .Callback<string, object[]>((_, o) => sqlParameters = o)
            .ReturnsAsync(expectedResult);

        _databaseTimeoutService
            .Setup(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()))
            .Verifiable();

        // Act 
        var result = await _sut.GetApprovedSubmissionsWithAggregatedPomData(approvedAfter, periods, includePackagingTypes, includePackagingMaterials, includeOrganisationSize);

        // Assert
        result.Should().NotBeNull();
        result.Count.Should().Be(10);
        sqlParameters.Should().BeEquivalentTo(new object[]
        {
            new SqlParameter("@ApprovedAfter", SqlDbType.DateTime2) { Value = approvedAfter },
            new SqlParameter("@Periods", SqlDbType.VarChar) { Value = periods },
            new SqlParameter("@IncludePackagingTypes", SqlDbType.VarChar) { Value = includePackagingTypes },
            new SqlParameter("@IncludePackagingMaterials", SqlDbType.VarChar) { Value = includePackagingMaterials },
            new SqlParameter("@IncludeOrganisationSize", SqlDbType.VarChar) { Value = includeOrganisationSize }
        });
        _databaseTimeoutService.Verify(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()), Times.Once);
    }

    [TestMethod]
    public async Task GetApprovedSubmissionsWithAggregatedPomData_WhenApprovedSubmissionsDoNotExist_ReturnsEmpty()
    {
        // Arrange
        var approvedAfter = DateTime.UtcNow;
        var periods = "2024-P1,2024-P2";
        var includePackagingTypes = "HH,NH,PB,HDC,NHC";
        var includePackagingMaterials = "AL,FC,GL,PC,PL,ST,WD";
        var includeOrganisationSize = "L";

        var sqlParameters = Array.Empty<object>();

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<ApprovedSubmissionEntity>(It.IsAny<string>(), It.IsAny<object[]>()))
            .Callback<string, object[]>((_, o) => sqlParameters = o)
            .ReturnsAsync(Array.Empty<ApprovedSubmissionEntity>());

        _databaseTimeoutService
            .Setup(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()))
            .Verifiable();

        // Act 
        var result = await _sut.GetApprovedSubmissionsWithAggregatedPomData(approvedAfter, periods, includePackagingTypes, includePackagingMaterials, includeOrganisationSize);

        // Assert
        result.Should().NotBeNull();
        result.Count.Should().Be(0);
        sqlParameters.Should().BeEquivalentTo(new object[]
        {
            new SqlParameter("@ApprovedAfter", SqlDbType.DateTime2) { Value = approvedAfter },
            new SqlParameter("@Periods", SqlDbType.VarChar) { Value = periods },
            new SqlParameter("@IncludePackagingTypes", SqlDbType.VarChar) { Value = includePackagingTypes },
            new SqlParameter("@IncludePackagingMaterials", SqlDbType.VarChar) { Value = includePackagingMaterials },
            new SqlParameter("@IncludeOrganisationSize", SqlDbType.VarChar) { Value = includeOrganisationSize }

        });
        _databaseTimeoutService.Verify(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()), Times.Once);
    }

    [TestMethod]
    public async Task GetApprovedSubmissionsWithAggregatedPomData_WhenExceptionOccurs_ShouldThrowDataException()
    {
        // Arrange
        var approvedAfter = DateTime.UtcNow;
        var periods = "2024-P1,2024-P2";
        var includePackagingTypes = "HH,NH,PB,HDC,NHC";
        var includePackagingMaterials = "AL,FC,GL,PC,PL,ST,WD";
        var includeOrganisationSize = "L";

        // Set up the mock to throw a generic exception when RunSqlAsync is called
        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<ApprovedSubmissionEntity>(It.IsAny<string>(), It.IsAny<object[]>()))
            .ThrowsAsync(new Exception("Simulated exception"));

        _databaseTimeoutService
            .Setup(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()))
            .Verifiable();

        // Act
        Func<Task> act = async () => await _sut.GetApprovedSubmissionsWithAggregatedPomData(approvedAfter, periods, includePackagingTypes, includePackagingMaterials, includeOrganisationSize);

        await act.Should().ThrowAsync<DataException>();

        // Assert - This will be handled by the ExpectedException attribute
        _databaseTimeoutService.Verify(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()), Times.Once);
    }

    [TestMethod]
    public async Task GetApprovedSubmissionsWithAggregatedPomData_WhenParametersAreNull_ExecutesWithNullParameter()
    {
        // Arrange
        var expectedResult = _fixture.Build<ApprovedSubmissionEntity>().CreateMany(5).ToList();
        var approvedAfter = DateTime.UtcNow;
        string? periods = null;
        string? includePackagingTypes = null;
        string? includePackagingMaterials = null;
        string? includeOrganisationSize = null;

        var sqlParameters = Array.Empty<object>();

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<ApprovedSubmissionEntity>(It.IsAny<string>(), It.IsAny<object[]>()))
            .Callback<string, object[]>((_, o) => sqlParameters = o)
            .ReturnsAsync(expectedResult);

        _databaseTimeoutService
            .Setup(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()))
            .Verifiable();

        // Act 
        var result = await _sut.GetApprovedSubmissionsWithAggregatedPomData(approvedAfter, periods!, includePackagingTypes!, includePackagingMaterials!, includeOrganisationSize!);

        // Assert
        result.Should().NotBeNull();
        result.Count.Should().Be(5);
        sqlParameters.Should().BeEquivalentTo(new object[]
        {
            new SqlParameter("@ApprovedAfter", SqlDbType.DateTime2) { Value = approvedAfter },
            new SqlParameter("@Periods", SqlDbType.VarChar) { Value = DBNull.Value }, // Check for DBNull when periods is null
			new SqlParameter("@IncludePackagingTypes", SqlDbType.VarChar) { Value = DBNull.Value }, // Check for DBNull when includePackagingTypes is null
			new SqlParameter("@IncludePackagingMaterials", SqlDbType.VarChar) { Value = DBNull.Value }, // Check for DBNull when includePackagingMaterials is null
            new SqlParameter("@IncludeOrganisationSize", SqlDbType.VarChar) { Value = DBNull.Value }  // Check for DBNull when includeOrganisationSize is null
        });
        _databaseTimeoutService.Verify(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()), Times.Once);
    }

    [TestMethod]
    public async Task GetApprovedSubmissionsWithAggregatedPomData_WhenParametersAreEmpty_ExecutesWithEmptyParameter()
    {
        // Arrange
        var expectedResult = _fixture.Build<ApprovedSubmissionEntity>().CreateMany(3).ToList();
        var approvedAfter = DateTime.UtcNow;
        var periods = ""; // Empty periods
        var includePackagingTypes = ""; // Empty includePackagingTypes
        var includePackagingMaterials = "";  // Empty includePackagingMaterials
        var includeOrganisationSize = ""; // Empty includeOrganisationSize

        var sqlParameters = Array.Empty<object>();

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<ApprovedSubmissionEntity>(It.IsAny<string>(), It.IsAny<object[]>()))
            .Callback<string, object[]>((_, o) => sqlParameters = o)
            .ReturnsAsync(expectedResult);

        _databaseTimeoutService
            .Setup(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()))
            .Verifiable();

        // Act 
        var result = await _sut.GetApprovedSubmissionsWithAggregatedPomData(approvedAfter, periods, includePackagingTypes, includePackagingMaterials, includeOrganisationSize);

        // Assert
        result.Should().NotBeNull();
        result.Count.Should().Be(3);
        sqlParameters.Should().BeEquivalentTo(new object[]
        {
            new SqlParameter("@ApprovedAfter", SqlDbType.DateTime2) { Value = approvedAfter },
            new SqlParameter("@Periods", SqlDbType.VarChar) { Value = periods }, // Check for empty string when periods is empty
			new SqlParameter("@IncludePackagingTypes", SqlDbType.VarChar) { Value = includePackagingTypes }, // Check for empty string when includePackagingTypes is empty
			new SqlParameter("@IncludePackagingMaterials", SqlDbType.VarChar) { Value = includePackagingMaterials }, // Check for empty string when includePackagingMaterials is empty
            new SqlParameter("@IncludeOrganisationSize", SqlDbType.VarChar) { Value = includeOrganisationSize }  // Check for empty string when includeOrganisationSize is empty
		});
        _databaseTimeoutService.Verify(x => x.SetCommandTimeout(It.IsAny<DbContext>(), It.IsAny<int>()), Times.Once);
    }

    [TestMethod]
    public void GetApprovedSubmissionsWithAggregatedPomData_WhenReceivesTimeout_WillThrowTimeoutException()
    {
        // Arrange
        var approvedAfter = DateTime.UtcNow;
        var periods = "2024-P1,2024-P2";
        var includePackagingTypes = "HH,NH,PB,HDC,NHC";
        var includePackagingMaterials = "AL,FC,GL,PC,PL,ST,WD";
        var includeOrganisationSize = "L";

        var sqlParameters = Array.Empty<object>();

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<ApprovedSubmissionEntity>(It.IsAny<string>(), It.IsAny<object[]>()))
            .Callback<string, object[]>((_, o) => sqlParameters = o)
            .ThrowsAsync(BuildSqlException(-2));

        // Act and Assert
        Assert.ThrowsExceptionAsync<TimeoutException>(() => _sut.GetApprovedSubmissionsWithAggregatedPomData(approvedAfter, periods, includePackagingTypes, includePackagingMaterials, includeOrganisationSize));
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissionSummaries_CallsStoredProcedure()
    {
        const int PageSize = 10;
        const int PageNumber = 2;

        var request = _fixture
                    .Build<OrganisationRegistrationFilterRequest>()
                    .With(x => x.PageSize, PageSize)
                    .With(x => x.PageNumber, PageNumber)
                    .Create();

        var submissionSummaries = _fixture
            .Build<OrganisationRegistrationSummaryDataRow>()
            .With(x => x.TotalItems, 100)
            .CreateMany(PageSize).ToList();

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<OrganisationRegistrationSummaryDataRow>(
                It.IsAny<string>(),
                It.IsAny<object[]>()))
            .ReturnsAsync(submissionSummaries).Verifiable();

        //Act
        var result = await _sut.GetOrganisationRegistrationSubmissionSummaries(1, request);

        //Assert
        result.Should().NotBeNull();

        _mockSynapseContext.Verify(
            x => x.RunSqlAsync<OrganisationRegistrationSummaryDataRow>(
                It.IsAny<string>(),
                It.IsAny<object[]>()
            ),
            Times.Once()
        );
    }

    [TestMethod]
    public void GetOrganisationRegistrationSubmissionSummaries_WillThrowTimeoutException_WhenTimoutExceptionOccurs()
    {
        const int PageSize = 10;
        const int PageNumber = 2;

        var request = _fixture
                    .Build<OrganisationRegistrationFilterRequest>()
                    .With(x => x.PageSize, PageSize)
                    .With(x => x.PageNumber, PageNumber)
                    .Create();

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<OrganisationRegistrationSummaryDataRow>(
                It.IsAny<string>(),
                It.IsAny<object[]>()))
            .Throws(BuildSqlException(-2));

        //Act and Assert
        Assert.ThrowsExceptionAsync<TimeoutException>(() => _sut.GetOrganisationRegistrationSubmissionSummaries(1, request));
    }

    [TestMethod]
    public void GetOrganisationRegistrationSubmissionSummaries_WillThrowDataException_WhenExceptionOccurs()
    {
        const int PageSize = 10;
        const int PageNumber = 2;

        var request = _fixture
                    .Build<OrganisationRegistrationFilterRequest>()
                    .With(x => x.PageSize, PageSize)
                    .With(x => x.PageNumber, PageNumber)
                    .Create();

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<OrganisationRegistrationSummaryDataRow>(
                It.IsAny<string>(),
                It.IsAny<object[]>()))
            .Throws(BuildSqlException(-1));

        //Act and Assert
        Assert.ThrowsExceptionAsync<DataException>(() => _sut.GetOrganisationRegistrationSubmissionSummaries(1, request));
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissionSummaries_WhenNoSubmissionsExist_Returns_EmptyPaginatedList()
    {
        const int PageSize = 10;
        const int PageNumber = 2;

        var request = _fixture
                    .Build<OrganisationRegistrationFilterRequest>()
                    .With(x => x.PageSize, PageSize)
                    .With(x => x.PageNumber, PageNumber)
                    .Create();

        var submissionSummaries = _fixture
            .Build<OrganisationRegistrationSummaryDataRow>()
            .With(x => x.TotalItems, 0)
            .CreateMany(0).ToList();

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<OrganisationRegistrationSummaryDataRow>(
                It.IsAny<string>(),
                It.IsAny<object[]>()))
            .ReturnsAsync(submissionSummaries).Verifiable();

        //Act
        var result = await _sut.GetOrganisationRegistrationSubmissionSummaries(1, request);

        //Assert
        result.Should().NotBeNull();
        result!.PageSize.Should().Be(10);
        result.TotalItems.Should().Be(0);
        result.CurrentPage.Should().Be(1);

        _mockSynapseContext.Verify(
            x => x.RunSqlAsync<OrganisationRegistrationSummaryDataRow>(
                It.IsAny<string>(),
                It.IsAny<object[]>()
            ),
            Times.Once()
        );
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissionSummaries_WhenThereAreSubmissions_Returns_Them()
    {
        const int PageSize = 20;
        const int PageNumber = 4;

        var request = _fixture
                    .Build<OrganisationRegistrationFilterRequest>()
                    .With(x => x.PageSize, PageSize)
                    .With(x => x.PageNumber, PageNumber)
                    .Create();

        var submissionSummaries = _fixture
            .Build<OrganisationRegistrationSummaryDataRow>()
            .With(x => x.TotalItems, 100)
            .CreateMany(PageSize).ToList();

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<OrganisationRegistrationSummaryDataRow>(
                It.IsAny<string>(),
                It.IsAny<object[]>()))
            .ReturnsAsync(submissionSummaries).Verifiable();

        //Act
        var result = await _sut.GetOrganisationRegistrationSubmissionSummaries(1, request);

        //Assert
        result.Should().NotBeNull();
        result!.PageSize.Should().Be(PageSize);
        result.TotalItems.Should().Be(100);
        result.CurrentPage.Should().Be(PageNumber);
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissionSummaries_WhenThereAreSubmissions_ButLessThanCurrentPage_Returns_LastPage()
    {
        const int PageSize = 20;
        const int PageNumber = 4;

        var request = _fixture
                    .Build<OrganisationRegistrationFilterRequest>()
                    .With(x => x.PageSize, PageSize)
                    .With(x => x.PageNumber, PageNumber)
                    .Create();

        var submissionSummaries = _fixture
            .Build<OrganisationRegistrationSummaryDataRow>()
            .With(x => x.TotalItems, PageSize + 10)
            .CreateMany(PageSize + 10).ToList();

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<OrganisationRegistrationSummaryDataRow>(
                It.IsAny<string>(),
                It.IsAny<object[]>()))
            .ReturnsAsync(submissionSummaries).Verifiable();

        //Act
        var result = await _sut.GetOrganisationRegistrationSubmissionSummaries(1, request);

        //Assert
        result.Should().NotBeNull();
        result!.PageSize.Should().Be(PageSize);
        result.TotalItems.Should().Be(PageSize + 10);
        result.CurrentPage.Should().Be(2);
    }

    private static SqlException? BuildSqlException(int number)
    {
        var errorConstructor = typeof(SqlError).GetConstructor(
            BindingFlags.NonPublic | BindingFlags.Instance,
            null,
            [typeof(int), typeof(byte), typeof(byte), typeof(string), typeof(string), typeof(string), typeof(int), typeof(System.Exception)],
            null
        );

        object? sqlError = errorConstructor?.Invoke([number,
            (byte)0,
            (byte)0,
            "server",
            "Custom SQL Error Message",
            "procedure",
            0,
            new Exception("A generic exception")]);

        SqlErrorCollection? errorCollection = Activator.CreateInstance(typeof(SqlErrorCollection), true) as SqlErrorCollection;
        typeof(SqlErrorCollection).GetMethod("Add", BindingFlags.NonPublic | BindingFlags.Instance)?
                                  .Invoke(errorCollection, [sqlError]);


        var exceptionConstructor = typeof(SqlException).GetConstructor(
            BindingFlags.NonPublic | BindingFlags.Instance,
            null,
            [typeof(string), typeof(SqlErrorCollection), typeof(Exception), typeof(Guid)],
            null
        );

        return exceptionConstructor?.Invoke(["Custom SQL Exception Message", errorCollection, null, Guid.NewGuid()]) as SqlException;
    }

    [TestMethod]
    public async Task GetOrganisationRegistrationSubmissionDetails_Will_Call_StoredProc()
    {
        var request = new OrganisationRegistrationDetailRequest { SubmissionId = Guid.NewGuid() };

        var submissionDto = _fixture
            .Build<OrganisationRegistrationDetailsDto>()
            .CreateMany(1).ToList();

        _mockSynapseContext
            .Setup(x => x.RunSpCommandAsync<OrganisationRegistrationDetailsDto>(
                It.IsAny<string>(),
                It.IsAny<ILogger>(),
                It.IsAny<string>(),
                It.IsAny<SqlParameter[]>()
            ))
            .ReturnsAsync(submissionDto).Verifiable();

        //Act
        var result = await _sut.GetOrganisationRegistrationSubmissionDetails(request);

        //Assert
        result.Should().NotBeNull();

        _mockSynapseContext.Verify(
            x => x.RunSpCommandAsync<OrganisationRegistrationDetailsDto>(
                It.IsAny<string>(),
                It.IsAny<ILogger>(),
                It.IsAny<string>(),
                It.IsAny<SqlParameter[]>()
            ),
            Times.Once()
        );

    }

    [TestMethod]
    public void GetOrganisationRegistrationSubmissionDetails_WillThrowTimeoutException_WhenTimoutExceptionOccurs()
    {
        var request = new OrganisationRegistrationDetailRequest { SubmissionId = Guid.NewGuid() };

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<OrganisationRegistrationDetailsDto>(
                It.IsAny<string>(),
                It.IsAny<object[]>()))
            .Throws(BuildSqlException(-2));
        _mockSynapseContext
            .Setup(x => x.RunSpCommandAsync<OrganisationRegistrationDetailsDto>(
                It.IsAny<string>(),
                It.IsAny<ILogger>(),
                It.IsAny<string>(),
                It.IsAny<SqlParameter[]>()))
            .Throws(BuildSqlException(-2));

        //Act and Assert
        Assert.ThrowsExceptionAsync<TimeoutException>(() => _sut.GetOrganisationRegistrationSubmissionDetails(request));
    }

    [TestMethod]
    public void GetOrganisationRegistrationSubmissionDetails_WillDataException_WhenInnerExceptionOccurs()
    {
        var request = new OrganisationRegistrationDetailRequest { SubmissionId = Guid.NewGuid() };

        _mockSynapseContext
            .Setup(x => x.RunSqlAsync<OrganisationRegistrationDetailsDto>(
                It.IsAny<string>(),
                It.IsAny<object[]>()))
            .Throws(BuildSqlException(-1));
        _mockSynapseContext
            .Setup(x => x.RunSpCommandAsync<OrganisationRegistrationDetailsDto>(
                It.IsAny<string>(),
                It.IsAny<ILogger>(),
                It.IsAny<string>(),
                It.IsAny<SqlParameter[]>()))
            .Throws(BuildSqlException(-1));

        Assert.ThrowsExceptionAsync<DataException>(() => _sut.GetOrganisationRegistrationSubmissionDetails(request));
    }

    //[TestMethod]
    public async Task GetOrganisationRegistrationSubmissionSummaries_RetrievesData_Correctly()
    {
        const int PageSize = 20;
        const int PageNumber = 1;

        var mockLogger = new Mock<ILogger<SubmissionsService>>();
        var configurationMock = new Mock<IConfiguration>();
        configurationMock.Setup(c => c["LogPrefix"]).Returns("[EPR.CommonDataService]");

        var request = new OrganisationRegistrationFilterRequest
        {
            PageNumber = PageNumber,
            PageSize = PageSize
        };

        var options = new DbContextOptionsBuilder<SynapseContext>().UseSqlServer(@"Server=localhost\MSSQLSERVER01;Initial Catalog=LocalSynapse;TrustServerCertificate=True;Trusted_Connection=true;Integrated Security=true;Pooling=False;")
                        .LogTo(Console.WriteLine, LogLevel.Information)
                        .Options;

        try
        {
            //using SynapseContext dbContext = new SynapseContext(options);
            //SubmissionsService svc = new(mockDb, _databaseTimeoutService.Object, mockLogger.Object, configurationMock.Object);

            var result = await _sut.GetOrganisationRegistrationSubmissionSummaries(1, request);

            result!.Items.Should().HaveCountGreaterThan(1);
        }
        catch (Exception ex)
        {
            Console.WriteLine(ex);
            throw;
        }

    }

    //[TestMethod]
    public async Task GetOrganisationRegistrationDetails_RetrievesData_Correctly()
    {
        //var mockLogger = new Mock<ILogger<SubmissionsService>>();
        //var configurationMock = new Mock<IConfiguration>();
        //configurationMock.Setup(c => c["LogPrefix"]).Returns("[EPR.CommonDataService]");

        var request = Guid.Parse("cf9b5bc0-e41a-47e3-bdbe-87388181f31c");

        //var options = new DbContextOptionsBuilder<SynapseContext>().UseSqlServer(@"Server=localhost\MSSQLSERVER01;Initial Catalog=LocalSynapse;TrustServerCertificate=True;Trusted_Connection=true;Integrated Security=true;Pooling=False;")
        //                .LogTo(Console.WriteLine, LogLevel.Debug)
        //                .Options;

        try
        {
            //using SynapseContext dbContext = new(options);
            //SubmissionsService svc = new(dbContext, _databaseTimeoutService.Object, mockLogger.Object, configurationMock.Object);

            var result = await _sut.GetOrganisationRegistrationSubmissionDetails(new OrganisationRegistrationDetailRequest { SubmissionId = request });

            result?.SubmissionId.Should().Be(request.ToString());
        }
        catch (Exception ex)
        {
            Console.WriteLine(ex);
            throw;
        }
    }


    [TestMethod]
    public async Task GetResubmissionPaycalParameters_ReturnsValidData()
    {
        // Arrange
        var mockData = new List<PomResubmissionPaycalParametersDto>
        {
            new PomResubmissionPaycalParametersDto { ReferenceFieldAvailable = true }
        };

        _mockSynapseContext
            .Setup(db => db.RunSpCommandAsync<PomResubmissionPaycalParametersDto>(
                It.IsAny<string>(),
                It.IsAny<ILogger>(),
                It.IsAny<string>(),
                It.IsAny<SqlParameter[]>()))
            .ReturnsAsync(mockData);

        // Act
        var result = await _sut.GetResubmissionPaycalParameters("1234", "5678");

        // Assert
        Assert.IsNotNull(result);
        Assert.IsTrue(result.ReferenceFieldAvailable);
    }

    [TestMethod]
    public async Task GetResubmissionPaycalParameters_ReturnsNull_WhenNoData()
    {
        // Arrange
        _mockSynapseContext
            .Setup(db => db.RunSpCommandAsync<PomResubmissionPaycalParametersDto>(
                It.IsAny<string>(),
                It.IsAny<ILogger>(),
                It.IsAny<string>(),
                It.IsAny<SqlParameter[]>()))
            .ReturnsAsync(new List<PomResubmissionPaycalParametersDto>());

        // Act
        var result = await _sut.GetResubmissionPaycalParameters("1234", "5678");

        // Assert
        Assert.IsNull(result);
    }

    [TestMethod]
    public async Task GetResubmissionPaycalParameters_ThrowsTimeoutException()
    {
        // Arrange
        _mockSynapseContext
            .Setup(db => db.RunSpCommandAsync<PomResubmissionPaycalParametersDto>(
                It.IsAny<string>(),
                It.IsAny<ILogger>(),
                It.IsAny<string>(),
                It.IsAny<SqlParameter[]>()))
            .ThrowsAsync(BuildSqlException(-2));

        // Act & Assert
        await Assert.ThrowsExceptionAsync<TimeoutException>(() => _sut.GetResubmissionPaycalParameters("1234", "5678"));
    }

    [TestMethod]
    public async Task GetResubmissionPaycalParameters_ThrowsDataException_When_SQLException_Occurs()
    {
        // Arrange
        _mockSynapseContext
            .Setup(db => db.RunSpCommandAsync<PomResubmissionPaycalParametersDto>(
                It.IsAny<string>(),
                It.IsAny<ILogger>(),
                It.IsAny<string>(),
                It.IsAny<SqlParameter[]>()))
            .ThrowsAsync(BuildSqlException(-1));

        // Act & Assert
        await Assert.ThrowsExceptionAsync<DataException>(() => _sut.GetResubmissionPaycalParameters("1234", "5678"));
    }

    [TestMethod]
    public async Task IsCosmosDataAvailable_Should_Return_False_When_DbSet_Is_Empty()
    {
        // Arrange
        _mockSynapseContext
            .Setup(db => db.RunSpCommandAsync<CosmosSyncInfo>(It.IsAny<string>(), It.IsAny<ILogger>(), It.IsAny<string>(), It.IsAny<SqlParameter[]>()))
            .ReturnsAsync(new List<CosmosSyncInfo>());

        // Act
        var result = await _sut.IsCosmosDataAvailable("submissionId", "fileId");

        // Assert
        result.Should().BeFalse();
    }

    [TestMethod]
    public async Task IsCosmosDataAvailable_Should_Return_True_When_IsSynced_Is_True()
    {
        // Arrange
        var mockData = new List<CosmosSyncInfo>
                        {
                            new CosmosSyncInfo { IsSynced = true }
                        };

        _mockSynapseContext
            .Setup(db => db.RunSpCommandAsync<CosmosSyncInfo>(It.IsAny<string>(), It.IsAny<ILogger>(), It.IsAny<string>(), It.IsAny<SqlParameter[]>()))
            .ReturnsAsync(mockData);

        // Act
        var result = await _sut.IsCosmosDataAvailable("submissionId", "fileId");

        // Assert
        result.Should().BeTrue();
    }

    [TestMethod]
    public async Task IsCosmosDataAvailable_Should_Return_False_When_IsSynced_Is_False()
    {
        // Arrange
        var mockData = new List<CosmosSyncInfo>
    {
        new CosmosSyncInfo { IsSynced = false }
    };

        _mockSynapseContext
            .Setup(db => db.RunSpCommandAsync<CosmosSyncInfo>(It.IsAny<string>(), It.IsAny<ILogger>(), It.IsAny<string>(), It.IsAny<SqlParameter[]>()))
            .ReturnsAsync(mockData);

        // Act
        var result = await _sut.IsCosmosDataAvailable("submissionId", "fileId");

        // Assert
        result.Should().BeFalse();
    }

    [TestMethod]
    public async Task IsCosmosDataAvailable_Should_Throw_TimeoutException_When_SqlException_With_Timeout_Occurs()
    {
        // Arrange
        var timeoutException = BuildSqlException(-2);
        _mockSynapseContext
            .Setup(db => db.RunSpCommandAsync<CosmosSyncInfo>(It.IsAny<string>(), It.IsAny<ILogger>(), It.IsAny<string>(), It.IsAny<SqlParameter[]>()))
            .ThrowsAsync(timeoutException);

        // Act
        Func<Task> act = async () => await _sut.IsCosmosDataAvailable("submissionId", "fileId");

        // Assert
        await act.Should().ThrowAsync<TimeoutException>()
            .WithMessage("The request timed out while accessing the database.");
    }

    [TestMethod]
    public async Task IsCosmosDataAvailable_Should_Throw_DataException_When_SqlException_Occurs()
    {
        // Arrange
        var sqlException = BuildSqlException(-1);
        _mockSynapseContext
            .Setup(db => db.RunSpCommandAsync<CosmosSyncInfo>(It.IsAny<string>(), It.IsAny<ILogger>(), It.IsAny<string>(), It.IsAny<SqlParameter[]>()))
            .ThrowsAsync(sqlException);

        // Act
        Func<Task> act = async () => await _sut.IsCosmosDataAvailable("submissionId", "fileId");

        // Assert
        await act.Should().ThrowAsync<DataException>()
            .WithMessage("An exception occurred when executing query.");
    }
}
