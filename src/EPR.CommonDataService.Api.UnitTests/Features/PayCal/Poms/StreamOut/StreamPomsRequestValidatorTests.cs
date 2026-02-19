using EPR.CommonDataService.Api.Features.PayCal.Poms.StreamOut;
using FluentValidation.TestHelper;
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.UnitTests.Features.PayCal.Poms.StreamOut;

[ExcludeFromCodeCoverage]
[TestClass]
public class StreamPomsRequestValidatorTests
{
    private StreamPomsRequestValidator _validator = null!;

    [TestInitialize]
    public void Setup()
    {
        _validator = new StreamPomsRequestValidator();
    }

    [TestMethod]
    public void Validate_WhenSubmissionYearIsNull_ShouldHaveValidationError()
    {
        // Arrange
        var request = new StreamPomsRequest { RelativeYear = null };

        // Act
        var result = _validator.TestValidate(request);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.RelativeYear);
    }

    [TestMethod]
    [DataRow(2025)]
    [DataRow(2026)]
    [DataRow(9999)]
    public void Validate_WhenSubmissionYearIsValid_ShouldNotHaveValidationError(int year)
    {
        // Arrange
        var request = new StreamPomsRequest { RelativeYear = year };

        // Act
        var result = _validator.TestValidate(request);

        // Assert
        result.ShouldNotHaveValidationErrorFor(x => x.RelativeYear);
    }

    [TestMethod]
    [DataRow(2024)]
    [DataRow(2000)]
    [DataRow(0)]
    [DataRow(-1)]
    public void Validate_WhenSubmissionYearIsLessThan2025_ShouldHaveValidationError(int year)
    {
        // Arrange
        var request = new StreamPomsRequest { RelativeYear = year };

        // Act
        var result = _validator.TestValidate(request);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.RelativeYear);
    }

    [TestMethod]
    public void Validate_WhenSubmissionYearIsGreaterThan9999_ShouldHaveValidationError()
    {
        // Arrange
        var request = new StreamPomsRequest { RelativeYear = 10000 };

        // Act
        var result = _validator.TestValidate(request);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.RelativeYear);
    }
}
