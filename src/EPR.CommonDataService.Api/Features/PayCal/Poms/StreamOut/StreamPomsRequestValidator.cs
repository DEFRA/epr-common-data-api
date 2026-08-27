using FluentValidation;

namespace EPR.CommonDataService.Api.Features.PayCal.Poms.StreamOut;

public sealed class StreamPomsRequestValidator
    : AbstractValidator<StreamPomsRequest>
{
    public StreamPomsRequestValidator()
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
