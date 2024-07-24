using EPR.CommonDataService.Api.Configuration;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Infrastructure;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.Controllers;
public class ApiControllerBase : ControllerBase
{
    private readonly string _baseProblemTypePath;

    public ApiControllerBase(IOptions<ApiConfig> baseApiConfigOptions)
    {
        _baseProblemTypePath= baseApiConfigOptions.Value.BaseProblemTypePath;
    }

    [NonAction]
    public override ActionResult ValidationProblem()
    {
        return base.ValidationProblem(type: $"{_baseProblemTypePath}validation".ToLower());
    }

    [NonAction]
    public override ActionResult ValidationProblem(
        string? detail = null,
        string? instance = null,
        int? statusCode = null,
        string? title = null,
        string? type = null,
        [ActionResultObjectValue] ModelStateDictionary? modelStateDictionary = null)
    {
        modelStateDictionary ??= ModelState;
        type = type ?? $"{_baseProblemTypePath}validation";

        ValidationProblemDetails? validationProblem;
        if (ProblemDetailsFactory == null)
        {
            // ProblemDetailsFactory may be null in unit testing scenarios. Improvise to make this more testable.
            validationProblem = new ValidationProblemDetails(modelStateDictionary)
            {
                Detail = detail,
                Instance = instance,
                Status = statusCode,
                Title = title,
                Type = type,
            };
        }
        else
        {
            validationProblem = ProblemDetailsFactory.CreateValidationProblemDetails(
                HttpContext,
                modelStateDictionary,
                statusCode: statusCode,
                title: title,
                type: type,
                detail: detail,
                instance: instance);
        }

        if (validationProblem is { Status: 400 })
        {
            // For compatibility with 2.x, continue producing BadRequestObjectResult instances if the status code is 400.
            return new BadRequestObjectResult(validationProblem);
        }

        return new ObjectResult(validationProblem)
        {
            StatusCode = validationProblem.Status
        };
    }

    [NonAction]
    public override ObjectResult Problem(
        string? detail = null,
        string? instance = null,
        int? statusCode = null,
        string? title = null,
        string? type = null)
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
        title = title ?? exceptionName;

        return base.Problem(
            detail, 
            instance, 
            statusCode, 
            title,
            $"{_baseProblemTypePath}{exceptionName}".ToLower());
    }
}
