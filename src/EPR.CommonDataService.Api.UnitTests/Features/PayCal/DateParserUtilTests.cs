using EPR.CommonDataService.Api.Features.PayCal;

using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.UnitTests.Features.PayCal;

[ExcludeFromCodeCoverage]
[TestClass]
public class DateParserUtilTests
{
    [TestMethod]
    public void ParseCutoff_WhenNull_ShouldReturnNull()
    {
        Assert.IsNull(DateParserUtil.ParseCutoff(null));
    }

    [TestMethod]
    public void ParseCutoff_WhenLegacyDateFormat_ShouldReturnEndOfDayUtc()
    {
        var result = DateParserUtil.ParseCutoff("2026-07-09");
        Assert.IsNotNull(result);
        Assert.AreEqual(new DateTimeOffset(2026, 7, 9, 23, 59, 59, 999, TimeSpan.Zero).AddTicks(9999), result.Value);
    }

    [TestMethod]
    public void ParseCutoff_WhenIsoUtcDateTimeOffset_ShouldReturnUtc()
    {
        var result = DateParserUtil.ParseCutoff("2026-07-09T23:59:59Z");
        Assert.IsNotNull(result);
        Assert.AreEqual(new DateTimeOffset(2026, 7, 9, 23, 59, 59, TimeSpan.Zero), result.Value);
    }

    [TestMethod]
    public void ParseCutoff_WhenInvalidFormat_ShouldThrowFormatException() =>
        Assert.ThrowsException<FormatException>(() => DateParserUtil.ParseCutoff("09/07/2026"));

    [TestMethod]
    [DataRow(null)]
    [DataRow("")]
    [DataRow(" ")]
    public void IsValidCutoff_WhenEmpty_ShouldReturnTrue(string? cutoff) =>
        Assert.IsTrue(DateParserUtil.IsValidCutoff(cutoff));

    [TestMethod]
    [DataRow("2026-07-09")]
    [DataRow("2026-07-09T23:59:59Z")]
    public void IsValidCutoff_WhenValidFormat_ShouldReturnTrue(string cutoff) =>
        Assert.IsTrue(DateParserUtil.IsValidCutoff(cutoff));

    [TestMethod]
    [DataRow("09/07/2026")]
    [DataRow("2026-07-09T23:59:59")]
    [DataRow("2026-07-09T23:59:59+01:00")]
    [DataRow("not-a-date")]
    public void IsValidCutoff_WhenInvalidFormat_ShouldReturnFalse(string cutoff) =>
        Assert.IsFalse(DateParserUtil.IsValidCutoff(cutoff));
}
