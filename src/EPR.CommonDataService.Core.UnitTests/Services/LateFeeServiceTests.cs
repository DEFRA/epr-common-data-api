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
            new() { RelevantYear = 2025, EarliestSubmissionDate = firstSubmittedDate }
        };

        // Act
        var result = _sut.UpdateLateFeeFlag(request, paycalParametersResponse);

        // Assert
        Assert.IsNotNull(result);
        result[0].IsLateFee.Should().BeTrue();
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
            new() { RelevantYear = 2026, EarliestSubmissionDate = DateTime.UtcNow, OrganisationSize = 'N' }
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
            RelevantYear = 2026, EarliestSubmissionDate = DateTime.UtcNow, OrganisationSize = 'N'
        };

        // Act
        var result = _sut.UpdateLateFeeFlag(request, producerPaycalParametersResponse);

        // Assert
        Assert.IsNotNull(result);
        result.IsLateFee.Should().BeFalse();
    }

    [TestMethod]
    [DataRow(2026, 1, 1, true, "CS", 10, 'L')]
    [DataRow(2025, 11, 1, true, "CS", 10, 'S')]
    [DataRow(2025, 10, 2, true, "CS", 10, 'L')]
    public void Cso_Should_Set_LateFee_To_True_When_RelYear_Is_Greater_Than_2025_But_Date_NotInRange(
        int year, int month, int day, bool isCso, string type, int cutOffMonth, char orgSize)
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
            new() { RelevantYear = 2026, IsCso = isCso, EarliestSubmissionDate = firstSubmittedDate, OrganisationSize = orgSize }
        };

        // Act
        var result = _sut.UpdateLateFeeFlag(request, paycalParametersResponse);

        // Assert
        Assert.IsNotNull(result);
        result[0].IsLateFee.Should().BeTrue();
    }

    [TestMethod]
    [DataRow(2026, 1, 1, false, "LP", 10, 'L')]
    [DataRow(2025, 11, 1, false, "LP", 10, 'L')]
    [DataRow(2025, 10, 2, false, "LP", 10, 'L')]
    [DataRow(2027, 1, 1, false, "SP", 4, 'S')]
    [DataRow(2025, 11, 1, false, "SP", 4, 'S')]
    [DataRow(2025, 10, 2, false, "SP", 4, 'S')]
    public void Producer_Should_Set_LateFee_To_True_When_RelYear_Is_Greater_Than_2025_But_Date_NotInRange(
        int year, int month, int day, bool isCso, string type, int cutOffMonth, char orgSize)
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
            RelevantYear = 2026, IsCso = isCso, EarliestSubmissionDate = firstSubmittedDate, OrganisationSize = orgSize
        };

        // Act
        var result = _sut.UpdateLateFeeFlag(request, producerPaycalParametersResponse);

        // Assert
        Assert.IsNotNull(result);
        result.IsLateFee.Should().BeTrue();
    }
}