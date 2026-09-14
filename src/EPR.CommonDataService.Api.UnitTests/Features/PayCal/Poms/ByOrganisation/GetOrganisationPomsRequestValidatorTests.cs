using EPR.CommonDataService.Api.Features.PayCal.Poms.ByOrganisation;
using FluentValidation.TestHelper;
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.UnitTests.Features.PayCal.Poms.ByOrganisation;

[ExcludeFromCodeCoverage]
[TestClass]
public class GetOrganisationPomsRequestValidatorTests
{
    private GetOrganisationPomsRequestValidator _validator = null!;

    [TestInitialize]
    public void Setup()
    {
        _validator = new GetOrganisationPomsRequestValidator();
    }

    [TestMethod]
    public void Validate_WhenOrganisationIdIsNull_ShouldHaveValidationError()
    {
        // Arrange
        var request = new GetOrganisationPomsRequest { OrganisationId = null };

        // Act
        var result = _validator.TestValidate(request);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.OrganisationId);
    }

    [TestMethod]
    [DataRow(0)]
    [DataRow(-1)]
    public void Validate_WhenOrganisationIdIsNotPositive_ShouldHaveValidationError(int organisationId)
    {
        // Arrange
        var request = new GetOrganisationPomsRequest { OrganisationId = organisationId };

        // Act
        var result = _validator.TestValidate(request);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.OrganisationId);
    }

    [TestMethod]
    public void Validate_WhenOrganisationIdIsPositive_ShouldNotHaveValidationError()
    {
        // Arrange
        var request = new GetOrganisationPomsRequest { OrganisationId = 103844 };

        // Act
        var result = _validator.TestValidate(request);

        // Assert
        result.ShouldNotHaveValidationErrorFor(x => x.OrganisationId);
    }

    [TestMethod]
    public void Validate_WhenRelativeYearIsNull_ShouldNotHaveValidationError()
    {
        // Arrange
        // Unlike the stream endpoint, the year is optional here: a single organisation's whole
        // history is a bounded query.
        var request = new GetOrganisationPomsRequest { OrganisationId = 103844, RelativeYear = null };

        // Act
        var result = _validator.TestValidate(request);

        // Assert
        result.ShouldNotHaveValidationErrorFor(x => x.RelativeYear);
    }

    [TestMethod]
    [DataRow(2025)]
    [DataRow(2026)]
    [DataRow(9999)]
    public void Validate_WhenRelativeYearIsValid_ShouldNotHaveValidationError(int year)
    {
        // Arrange
        var request = new GetOrganisationPomsRequest { OrganisationId = 103844, RelativeYear = year };

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
    public void Validate_WhenRelativeYearIsLessThan2025_ShouldHaveValidationError(int year)
    {
        // Arrange
        // The underlying procedure joins to registrations filtered to SubmissionPeriodYear > 2024,
        // so an earlier year cannot return rows.
        var request = new GetOrganisationPomsRequest { OrganisationId = 103844, RelativeYear = year };

        // Act
        var result = _validator.TestValidate(request);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.RelativeYear);
    }

    [TestMethod]
    public void Validate_WhenRelativeYearIsGreaterThan9999_ShouldHaveValidationError()
    {
        // Arrange
        var request = new GetOrganisationPomsRequest { OrganisationId = 103844, RelativeYear = 10000 };

        // Act
        var result = _validator.TestValidate(request);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.RelativeYear);
    }

    [TestMethod]
    [DataRow("2026-01-01")]
    [DataRow("2026-01-01T00:00:00Z")]
    [DataRow("2026-01-01T00:00:00.1234567Z")]
    [DataRow(null)]
    public void Validate_WhenCutOffDateIsValid_ShouldNotHaveValidationError(string? cutOffDate)
    {
        // Arrange
        var request = new GetOrganisationPomsRequest { OrganisationId = 103844, CutOffDate = cutOffDate };

        // Act
        var result = _validator.TestValidate(request);

        // Assert
        result.ShouldNotHaveValidationErrorFor(x => x.CutOffDate);
    }

    [TestMethod]
    [DataRow("last Tuesday")]
    [DataRow("01-01-2026")]
    // A numeric offset is not accepted, only a literal Z. Worth pinning: it is the form most
    // clients produce by default, and DateParserUtil rejects it.
    [DataRow("2026-01-01T00:00:00+00:00")]
    public void Validate_WhenCutOffDateIsMalformed_ShouldHaveValidationError(string cutOffDate)
    {
        // Arrange
        var request = new GetOrganisationPomsRequest { OrganisationId = 103844, CutOffDate = cutOffDate };

        // Act
        var result = _validator.TestValidate(request);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.CutOffDate);
    }
}
