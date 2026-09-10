using FluentValidation;

namespace EPR.CommonDataService.Api.Features.PayCal.Poms.ByOrganisation;

public sealed class GetOrganisationPomsRequestValidator
    : AbstractValidator<GetOrganisationPomsRequest>
{
    public GetOrganisationPomsRequestValidator()
    {
        RuleFor(request => request.OrganisationId)
            .NotNull()
            .GreaterThan(0);

        // Optional here, unlike the PayCal stream, because a single organisation's whole history is
        // a bounded query. The 2025 floor still applies when a year IS supplied: the underlying
        // procedure joins to registrations filtered to SubmissionPeriodYear > 2024, so an earlier
        // year cannot return rows and a caller is better told that than handed an empty list.
        RuleFor(request => request.RelativeYear)
            .GreaterThanOrEqualTo(2025)
            .LessThanOrEqualTo(9999)
            .When(request => request.RelativeYear.HasValue);

        RuleFor(request => request.CutOffDate)
            .Must(DateParserUtil.IsValidCutoff)
            .WithMessage("CutOffDate must be in yyyy-MM-dd or ISO 8601 DateTimeOffset format.");
    }
}
