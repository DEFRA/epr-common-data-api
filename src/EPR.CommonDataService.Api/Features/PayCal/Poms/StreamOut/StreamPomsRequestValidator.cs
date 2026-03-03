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
    }
}