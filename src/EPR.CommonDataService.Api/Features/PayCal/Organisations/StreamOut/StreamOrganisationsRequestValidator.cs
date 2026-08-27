using FluentValidation;

namespace EPR.CommonDataService.Api.Features.PayCal.Organisations.StreamOut;

public sealed class StreamOrganisationsRequestValidator
    : AbstractValidator<StreamOrganisationsRequest>
{
    public StreamOrganisationsRequestValidator()
    {
        RuleFor(request => request.RelativeYear)
            .NotNull()
            .GreaterThanOrEqualTo(2025) // First valid EPR year
            .LessThanOrEqualTo(9999);

        RuleFor(request => request.CutOffDate)
            .Must(DateParserUtil.IsValidCutoff)
            .WithMessage("CutOffDate must be in yyyy-MM-dd or ISO 8601 DateTimeOffset format.");

    }
}
