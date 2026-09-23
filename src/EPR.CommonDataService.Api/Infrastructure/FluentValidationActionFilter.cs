using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.Infrastructure;

/// <summary>
///     Runs registered <see cref="IValidator{T}" /> instances for each bound action argument.
///     When validation fails, short-circuits the pipeline with a <see cref="ValidationProblemDetails" />
///     400 response using the same factory as <c>[ApiController]</c>, so callers receive a
///     consistent <c>application/problem+json</c> error body regardless of whether the failure
///     originated from data annotations or FluentValidation.
/// </summary>
public class FluentValidationActionFilter(
    IServiceProvider serviceProvider,
    IOptions<ApiBehaviorOptions> apiBehaviorOptions) : IAsyncActionFilter
{
    private readonly Func<ActionContext, IActionResult> invalidModelStateFactory =
        apiBehaviorOptions.Value.InvalidModelStateResponseFactory;

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        foreach (var argument in context.ActionArguments.Values)
        {
            if (argument is null)
                continue;

            var validatorType = typeof(IValidator<>).MakeGenericType(argument.GetType());

            if (serviceProvider.GetService(validatorType) is IValidator validator)
            {
                var validationContext = new ValidationContext<object>(argument);
                var result = await validator.ValidateAsync(validationContext, context.HttpContext.RequestAborted);

                foreach (var error in result.Errors)
                    context.ModelState.AddModelError(error.PropertyName, error.ErrorMessage);
            }
        }

        if (!context.ModelState.IsValid)
        {
            context.Result = invalidModelStateFactory(context);
            return;
        }

        await next();
    }
}