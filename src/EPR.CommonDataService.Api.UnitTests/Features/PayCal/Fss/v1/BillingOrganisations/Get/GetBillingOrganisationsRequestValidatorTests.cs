using System.Diagnostics.CodeAnalysis;
using EPR.CommonDataService.Api.Features.PayCal.Fss.v1.BillingOrganisations.Get;
using FluentValidation.TestHelper;

namespace EPR.CommonDataService.Api.UnitTests.Features.PayCal.Fss.v1.BillingOrganisations.Get;

[ExcludeFromCodeCoverage]
[TestClass]
public class GetBillingOrganisationsRequestValidatorTests
{
    private GetBillingOrganisationsRequestValidator _validator = null!;

    [TestInitialize]
    public void Setup()
    {
        _validator = new GetBillingOrganisationsRequestValidator();
    }

    [TestMethod]
    public void Validate_WhenFinancialYearIsNull_ShouldNotHaveValidationError()
    {
        // Arrange
        var request = new GetBillingOrganisationsRequest { FinancialYear = null };

        // Act
        var result = _validator.TestValidate(request);

        // Assert
        result.ShouldNotHaveValidationErrorFor(x => x.FinancialYear);
    }

    [TestMethod]
    [DataRow("2024-25")]
    [DataRow("2025-26")]
    [DataRow("2099-00")]
    public void Validate_WhenFinancialYearIsValid_ShouldNotHaveValidationError(string financialYear)
    {
        // Arrange
        var request = new GetBillingOrganisationsRequest { FinancialYear = financialYear };

        // Act
        var result = _validator.TestValidate(request);

        // Assert
        result.ShouldNotHaveValidationErrorFor(x => x.FinancialYear);
    }

    [TestMethod]
    [DataRow("")]
    [DataRow("2025")]
    [DataRow("2025-27")]
    [DataRow("2025/26")]
    [DataRow("2025-2026")]
    [DataRow("2000-01")]
    [DataRow("abcd-ef")]
    [DataRow("+202-26")]
    public void Validate_WhenFinancialYearIsInvalid_ShouldHaveValidationError(string financialYear)
    {
        // Arrange
        var request = new GetBillingOrganisationsRequest { FinancialYear = financialYear };

        // Act
        var result = _validator.TestValidate(request);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.FinancialYear)
            .WithErrorMessage("Financial year must be in the format YYYY-YY.");
    }
}
