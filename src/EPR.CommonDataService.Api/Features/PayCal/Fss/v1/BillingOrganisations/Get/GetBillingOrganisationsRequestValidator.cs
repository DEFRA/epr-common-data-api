using FluentValidation;

namespace EPR.CommonDataService.Api.Features.PayCal.Fss.v1.BillingOrganisations.Get;

public sealed class GetBillingOrganisationsRequestValidator
    : AbstractValidator<GetBillingOrganisationsRequest>
{
    public GetBillingOrganisationsRequestValidator()
    {
        RuleFor(request => request.FinancialYear)
            .Must(FinancialYear.IsValid)
            .When(request => request.FinancialYear is not null)
            .WithMessage("Financial year must be in the format YYYY-YY.");
    }
}
