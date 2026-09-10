using EPR.CommonDataService.Api.Configuration;
using FluentValidation;
using Microsoft.Extensions.Logging;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Infrastructure;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.Controllers;
public class ApiControllerBase(
    IOptions<ApiConfig> baseApiConfigOptions) 
    : ControllerBase
{
    private readonly string _baseProblemTypePath = baseApiConfigOptions.Value.BaseProblemTypePath;

    [NonAction]
    public override ActionResult ValidationProblem()
    {
        return base.ValidationProblem(type: $"{_baseProblemTypePath}validation".ToLower());
    }

    /// <summary>
    ///     Validates a request and, when it fails, logs the errors, records them on ModelState and
    ///     returns a ValidationProblem. Returns null when the request is valid.
    ///     Callers reject before touching the database, since the queries behind these endpoints
    ///     are expensive.
    /// </summary>
    [NonAction]
    protected async Task<ActionResult?> ValidateAsync<T>(
        IValidator<T> validator,
        T request,
        ILogger logger,
        string operation,
        CancellationToken cancellationToken)
    {
        var validationResult = await validator.ValidateAsync(request, cancellationToken);

        if (validationResult.IsValid) return null;

        logger.LogInformation("{Operation}: Invalid request. Errors={Errors}",
            operation,
            string.Join("; ", validationResult.Errors.Select(e => $"{e.PropertyName}: {e.ErrorMessage}")));

        foreach (var error in validationResult.Errors)
            ModelState.AddModelError(error.PropertyName, error.ErrorMessage);

        return ValidationProblem();
    }

    [NonAction]
    public override ActionResult ValidationProblem(
        string? detail,
        string? instance,
        int? statusCode,
        string? title,
        string? type,
        [ActionResultObjectValue] ModelStateDictionary? modelStateDictionary)
    {
        return base.ValidationProblem(detail, instance, statusCode, title, $"{_baseProblemTypePath}validation", modelStateDictionary);
    }

    [NonAction]
    public override ActionResult ValidationProblem(
        string? detail = null,
        string? instance = null,
        int? statusCode = null,
        string? title = null,
        string? type = null,
        [ActionResultObjectValue] ModelStateDictionary? modelStateDictionary = null,
        IDictionary<string, object?>? extensions = null)
    {
        return base.ValidationProblem(detail, instance, statusCode, title, $"{_baseProblemTypePath}validation", modelStateDictionary, extensions);
    }

    [NonAction]
    public override ObjectResult Problem(
        string? detail,
        string? instance,
        int? statusCode,
        string? title,
        string? type)
    {
        return base.Problem(detail, instance, statusCode, title, $"{_baseProblemTypePath}{type}".ToLower());
    }

    [NonAction]
    public ObjectResult Problem(
        Exception type,
        string? detail = null,
        string? instance = null,
        int? statusCode = null,
        string? title = null)
    {
        var exceptionName = type.GetType().Name;
        title ??= exceptionName;

        return base.Problem(detail, instance, statusCode, title, $"{_baseProblemTypePath}{exceptionName}".ToLower());
    }
}
