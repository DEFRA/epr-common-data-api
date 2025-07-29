using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Core.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using System.Data;

namespace EPR.CommonDataService.Core.UnitTests.Services;

[TestClass]
public class LateFeeServiceTests
{
    private LateFeeService _sut = null!;

    [TestInitialize]
    public void Setup()
    {
        var mockLogger = new Mock<ILogger<LateFeeService>>();
        var configurationMock = new Mock<IConfiguration>();
        configurationMock.Setup(c => c["LogPrefix"]).Returns("[EPR.CommonDataService]");
        _sut = new LateFeeService(mockLogger.Object, configurationMock.Object);
    }

    [TestMethod]
    public void Cso_UpdateLateFeeFlag_Should_Set_LateFee_To_False_When_RelevantYear_Is_Invalid()
    {
        // Arrange
        var paycalParametersResponse = new List<CsoPaycalParametersResponse>
        {
            new() { RelevantYear = 2024 }
        };
        var request = new Dictionary<string, string>
        {
            { "LateFeeCutOffMonth_2025", "4" },
            { "LateFeeCutOffDay_2025", "1" }
        };

        // Act
        var result = _sut.UpdateLateFeeFlag(request, paycalParametersResponse);

        // Assert
        Assert.IsNotNull(result);
        result[0].IsLateFee.Should().BeFalse();
    }

    [TestMethod]
    public void Producer_UpdateLateFeeFlag_Should_Set_LateFee_To_False_When_RelevantYear_Is_Invalid()
    {
        // Arrange
        var producerPaycalParametersResponse = new ProducerPaycalParametersResponse
        {
            RelevantYear = 2024
        };
        var request = new Dictionary<string, string>
        {
            { "LateFeeCutOffMonth_2025", "4" },
            { "LateFeeCutOffDay_2025", "1" }
        };

        // Act
        var result = _sut.UpdateLateFeeFlag(request, producerPaycalParametersResponse);

        // Assert
        Assert.IsNotNull(result);
        result.IsLateFee.Should().BeFalse();
    }

    [TestMethod]
    public void Cso_UpdateLateFeeFlag_Should_Set_LateFee_To_False_When_LateFeeSettings_Is_Null()
    {        
        var paycalParametersResponse = new List<CsoPaycalParametersResponse> 
        {
            new() { RelevantYear = 2025 }
        };

        // Act
        var result = _sut.UpdateLateFeeFlag(default!, paycalParametersResponse);

        // Assert
        Assert.IsNotNull(result);
        result[0].IsLateFee.Should().BeFalse();
    }

    [TestMethod]
    public void Producer_UpdateLateFeeFlag_Should_Set_LateFee_To_False_When_LateFeeSettings_Is_Null()
    {
        var producerPaycalParametersResponse = new ProducerPaycalParametersResponse
        {
             RelevantYear = 2025
        };

        // Act
        var result = _sut.UpdateLateFeeFlag(default!, producerPaycalParametersResponse);

        // Assert
        Assert.IsNotNull(result);
        result.IsLateFee.Should().BeFalse();
    }

    [TestMethod]
    [DataRow(2026, 1, 1)]
    [DataRow(2025, 11, 1)]
    [DataRow(2025, 10, 2)]
    public void Cso_Should_Set_LateFee_To_True_When_RelYear_Is_2025_But_Date_NotInRange(int year, int month, int day)
    {
        // Arrange
        var request = new Dictionary<string, string>
        {
            { "LateFeeCutOffMonth_2025", "4" },
            { "LateFeeCutOffDay_2025", "1" }
        };
        var firstSubmittedDate = new DateTime(year, month, day, 0, 0, 0, DateTimeKind.Utc);
        var paycalParametersResponse = new List<CsoPaycalParametersResponse>
        {
            new() { RelevantYear = 2025, EarliestSubmissionDate = firstSubmittedDate, FirstSubmittedOn = firstSubmittedDate }
        };

        // Act
        var result = _sut.UpdateLateFeeFlag(request, paycalParametersResponse);

        // Assert
        Assert.IsNotNull(result);
        result[0].IsLateFee.Should().BeTrue();
    }

    [TestMethod]
    [DataRow(2026, 1, 1, 2025, 11, 1)]
    [DataRow(2025, 11, 1, 2025, 10, 2)]
    [DataRow(2025, 10, 2, 2025, 10, 2)]
    public void Cso_Should_Set_LateFee_To_True_When_EarliestDate_Is_Late_And_NewJoiner_Is_True(int year, int month, int day, int firstSubmittedYear, int firstSubmittedMonth, int firstSubmittedDay)
    {
        var request = new Dictionary<string, string>
        {
            { "LateFeeCutOffMonth_2025", "4" },
            { "LateFeeCutOffDay_2025", "1" }
        };

        var firstSubmittedDate = new DateTime(firstSubmittedYear, firstSubmittedMonth, firstSubmittedDay, 0, 0, 0, DateTimeKind.Utc);
        var earliestSubmittedDate = new DateTime(year, month, day, 0, 0, 0, DateTimeKind.Utc);
        var paycalParametersResponse = new List<CsoPaycalParametersResponse>
        {
            new() { RelevantYear = 2025, EarliestSubmissionDate = earliestSubmittedDate, FirstSubmittedOn = firstSubmittedDate, IsNewJoiner = true }
        };

        // Act
        var result = _sut.UpdateLateFeeFlag(request, paycalParametersResponse);

        // Assert
        Assert.IsNotNull(result);
        result[0].IsLateFee.Should().BeTrue();
    }

    [TestMethod]
    [DataRow(2026, 1, 1, 2025, 8, 1)]
    [DataRow(2025, 11, 1, 2025, 8, 1)]
    [DataRow(2025, 10, 2, 2025, 8, 1)]
    public void Cso_Should_Set_LateFee_To_False_When_EarliestDate_Is_NotLate_And_NewJoiner_Is_False(int year, int month, int day, int firstSubmittedYear, int firstSubmittedMonth, int firstSubmittedDay)
    {
        var request = new Dictionary<string, string>
        {
            { "LateFeeCutOffMonth_2025", "10" },
            { "LateFeeCutOffDay_2025", "1" }
        };

        var firstSubmittedDate = new DateTime(firstSubmittedYear, firstSubmittedMonth, firstSubmittedDay, 0, 0, 0, DateTimeKind.Utc);
        var earliestSubmittedDate = new DateTime(year, month, day, 0, 0, 0, DateTimeKind.Utc);
        var paycalParametersResponse = new List<CsoPaycalParametersResponse>
        {
            new() { RelevantYear = 2025, EarliestSubmissionDate = earliestSubmittedDate, FirstSubmittedOn = firstSubmittedDate, IsNewJoiner = false }
        };

        // Act
        var result = _sut.UpdateLateFeeFlag(request, paycalParametersResponse);

        // Assert
        Assert.IsNotNull(result);
        result[0].IsLateFee.Should().BeFalse();
    }


    [TestMethod]
    [DataRow(2026, 1, 1)]
    [DataRow(2025, 11, 1)]
    [DataRow(2025, 10, 2)]
    public void Producer_Should_Set_LateFee_To_True_When_RelYear_Is_2025_But_Date_NotInRange(int year, int month, int day)
    {
        // Arrange
        var request = new Dictionary<string, string>
        {
            { "LateFeeCutOffMonth_2025", "4" },
            { "LateFeeCutOffDay_2025", "1" }
        };
        var firstSubmittedDate = new DateTime(year, month, day, 0, 0, 0, DateTimeKind.Utc);
        var producerPaycalParametersResponse = new ProducerPaycalParametersResponse
        {
            RelevantYear = 2025, EarliestSubmissionDate = firstSubmittedDate
        };

        // Act
        var result = _sut.UpdateLateFeeFlag(request, producerPaycalParametersResponse);

        // Assert
        Assert.IsNotNull(result);
        result.IsLateFee.Should().BeTrue();
    }

    [TestMethod]
    [DataRow(2025, 07, 13)]
    [DataRow(2025, 4, 5)]
    [DataRow(2025, 3, 2)]
    public void Small_Producer_Should_Set_LateFee_To_False_When_RelYear_Is_2026_And_Month_And_Date_InRange(int year, int month, int day)
    {
        // Arrange
        var request = new Dictionary<string, string>
        {
            { "LateFeeCutOffMonth_2025", "4" },
            { "LateFeeCutOffDay_2025", "1" },
            { "LateFeeCutOffMonth_SP", "4" },
            { "LateFeeCutOffDay_SP", "1" }
        };
        var firstSubmittedDate = new DateTime(year, month, day, 0, 0, 0, DateTimeKind.Utc);
        var producerPaycalParametersResponse = new ProducerPaycalParametersResponse
        {
            RelevantYear = 2026,
            EarliestSubmissionDate = firstSubmittedDate,
            OrganisationSize = "S"
        };

        // Act
        var result = _sut.UpdateLateFeeFlag(request, producerPaycalParametersResponse);

        // Assert
        Assert.IsNotNull(result);
        result.IsLateFee.Should().BeFalse();
    }

    [TestMethod]
    public void Cso_Should_Set_LateFee_To_False_When_RelYear_Is_Greater_Than_2025_But_Invalid_Response()
    {
        // Arrange
        var request = new Dictionary<string, string>
        {
            { "LateFeeCutOffMonth_SP", "10" },
            { "LateFeeCutOffDay_SP", "1" }
        };
        var paycalParametersResponse = new List<CsoPaycalParametersResponse>
        {
            new() { RelevantYear = 2026, EarliestSubmissionDate = DateTime.UtcNow, OrganisationSize = "N" }
        };

        // Act
        var result = _sut.UpdateLateFeeFlag(request, paycalParametersResponse);

        // Assert
        Assert.IsNotNull(result);
        result[0].IsLateFee.Should().BeFalse();
    }

    [TestMethod]
    public void Producer_Should_Set_LateFee_To_False_When_RelYear_Is_Greater_Than_2025_But_Invalid_Response()
    {
        // Arrange
        var request = new Dictionary<string, string>
        {
            { "LateFeeCutOffMonth_SP", "10" },
            { "LateFeeCutOffDay_SP", "1" }
        };
        var producerPaycalParametersResponse = new ProducerPaycalParametersResponse
        {
            RelevantYear = 2026, EarliestSubmissionDate = DateTime.UtcNow, OrganisationSize = "N"
        };

        // Act
        var result = _sut.UpdateLateFeeFlag(request, producerPaycalParametersResponse);

        // Assert
        Assert.IsNotNull(result);
        result.IsLateFee.Should().BeFalse();
    }

    [TestMethod]
    [DataRow(2026, 1, 1, true, "CS", 10, "L")]
    [DataRow(2025, 11, 1, true, "CS", 10, "S")]
    [DataRow(2025, 10, 2, true, "CS", 10, "L")]
    public void Cso_Should_Set_LateFee_To_True_When_RelYear_Is_Greater_Than_2025_But_Date_NotInRange(
        int year, int month, int day, bool isCso, string type, int cutOffMonth, string organisationSize)
    {
        // Arrange
        var request = new Dictionary<string, string>
        {
            { $"LateFeeCutOffMonth_{type}", cutOffMonth.ToString() },
            { $"LateFeeCutOffDay_{type}", "1" }
        };
        var firstSubmittedDate = new DateTime(year, month, day, 0, 0, 0, DateTimeKind.Utc);
        var paycalParametersResponse = new List<CsoPaycalParametersResponse>
        {
            new() { RelevantYear = 2026, IsCso = isCso, EarliestSubmissionDate = firstSubmittedDate, FirstSubmittedOn = firstSubmittedDate, OrganisationSize = organisationSize }
        };

        // Act
        var result = _sut.UpdateLateFeeFlag(request, paycalParametersResponse);

        // Assert
        Assert.IsNotNull(result);
        result[0].IsLateFee.Should().BeTrue();
    }

    [TestMethod]
    [DataRow(2026, 1, 1, false, "LP", 10, "L")]
    [DataRow(2025, 11, 1, false, "LP", 10, "L")]
    [DataRow(2025, 10, 2, false, "LP", 10, "L")]
    [DataRow(2027, 1, 1, false, "SP", 4, "S")]
    public void Producer_Should_Set_LateFee_To_True_When_RelYear_Is_Greater_Than_2025_But_Date_NotInRange(
        int year, int month, int day, bool isCso, string type, int cutOffMonth, string organisationSize)
    {
        // Arrange
        var request = new Dictionary<string, string>
        {
            { $"LateFeeCutOffMonth_{type}", cutOffMonth.ToString() },
            { $"LateFeeCutOffDay_{type}", "1" }
        };
        var firstSubmittedDate = new DateTime(year, month, day, 0, 0, 0, DateTimeKind.Utc);
        var producerPaycalParametersResponse = new ProducerPaycalParametersResponse
        {
            RelevantYear = 2026, IsCso = isCso, EarliestSubmissionDate = firstSubmittedDate, FirstSubmittedOn = firstSubmittedDate, OrganisationSize = organisationSize
        };

        // Act
        var result = _sut.UpdateLateFeeFlag(request, producerPaycalParametersResponse);

        // Assert
        Assert.IsNotNull(result);
        result.IsLateFee.Should().BeTrue();
    }
}