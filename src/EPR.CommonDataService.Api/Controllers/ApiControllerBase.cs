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
        _baseProblemTypePath = baseApiConfigOptions.Value.BaseProblemTypePath;
    }

    [NonAction]
    public override ActionResult ValidationProblem()
    {
        return base.ValidationProblem(type: $"{_baseProblemTypePath}validation".ToLower());
    }

    [NonAction]
    public override ActionResult ValidationProblem(
        // ReSharper disable once MethodOverloadWithOptionalParameter
        string? detail = null,
        string? instance = null,
        int? statusCode = null,
        string? title = null,
        string? type = null,
        [ActionResultObjectValue] ModelStateDictionary? modelStateDictionary = null)
    {
        return base.ValidationProblem(detail, instance, statusCode, title, $"{_baseProblemTypePath}validation", modelStateDictionary);
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
        title ??= exceptionName;

        return base.Problem(detail, instance, statusCode, title, $"{_baseProblemTypePath}{exceptionName}".ToLower());
    }
}
