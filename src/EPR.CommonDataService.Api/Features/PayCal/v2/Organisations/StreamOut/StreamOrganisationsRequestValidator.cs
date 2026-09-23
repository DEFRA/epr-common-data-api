using FluentValidation;

namespace EPR.CommonDataService.Api.Features.PayCal.v2.Organisations.StreamOut;

public sealed class StreamOrganisationsRequestValidator
    : AbstractValidator<StreamOrganisationsRequest>
{
    public StreamOrganisationsRequestValidator()
    {
        RuleFor(request => request.RelativeYear)
            .NotNull()
            .GreaterThanOrEqualTo(2025) // First valid EPR year
            .LessThanOrEqualTo(9999);
    }
}
