using EPR.CommonDataService.Api.Configuration;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Infrastructure;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.Extensions.Options;
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.UnitTests.Controllers;

[ExcludeFromCodeCoverage]
public class StubProblemDetailsFactory(ValidationProblemDetails validationProblemDetails) : ProblemDetailsFactory
{
    public override ValidationProblemDetails CreateValidationProblemDetails(
        HttpContext httpContext,
        ModelStateDictionary modelStateDictionary,
        int? statusCode = null,
        string? title = null,
        string? type = null,
        string? detail = null,
        string? instance = null)
    {
        //this is just a stub class and specific input or output are not relevant for scope of testing
        return validationProblemDetails;
    }

    public override ProblemDetails CreateProblemDetails(
        HttpContext httpContext,
        int? statusCode = null,
        string? title = null,
        string? type = null,
        string? detail = null,
        string? instance = null)
    {
        return new ProblemDetails
        {
            Status = statusCode,
            Title = title,
            Type = type,
            Detail = detail,
            Instance = instance
        };
    }
}

[ExcludeFromCodeCoverage]
[TestClass]
public class ApiControllerBaseTests
{
    private Mock<IOptions<ApiConfig>> _mockOptions = null!;
    private ApiControllerBase _controller = null!;

    [TestInitialize]
    public void TestInitialize()
    {
        _mockOptions = new Mock<IOptions<ApiConfig>>();
        _mockOptions.Setup(o => o.Value).Returns(new ApiConfig { BaseProblemTypePath = "https://epr-errors/" });

        _controller = new ApiControllerBase(_mockOptions.Object)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext()
            }
        };
    }

    [TestMethod]
    public void ValidationProblem_Without_Any_Param_ShouldReturnObjectResult_WithNull_StatusCode()
    {
        // Act
        var result = _controller.ValidationProblem();

        // Assert
        result.Should().BeOfType<ObjectResult>();
        var objectResult = result as ObjectResult;
        objectResult.Should().NotBeNull();
        objectResult!.StatusCode.HasValue.Should().BeFalse();
    }

    [TestMethod]
    public void ValidationProblem_WithModelState_ShouldReturnBadRequestObjectResult_WithExpectedType()
    {
        // Arrange
        var modelState = new ModelStateDictionary();
        modelState.AddModelError("key", "error");

        // Act
        var result = _controller.ValidationProblem(modelStateDictionary: modelState, statusCode: 400);

        // Assert
        result.Should().BeOfType<BadRequestObjectResult>();
        var badRequestResult = result as BadRequestObjectResult;
        badRequestResult!.Value.Should().BeOfType<ValidationProblemDetails>();
        var validationProblemDetails = badRequestResult.Value as ValidationProblemDetails;
        validationProblemDetails!.Type.Should().Be("https://epr-errors/validation");
        validationProblemDetails.Errors.Should().ContainKey("key");
    }

    [TestMethod]
    public void ValidationProblem_ModelStateDictionaryIsNull_SetsDefaultModelState()
    {
        // Arrange
        // Act
        var result = _controller.ValidationProblem(modelStateDictionary: null!, statusCode: 400);

        // Assert
        var objectResult = result.Should().BeOfType<BadRequestObjectResult>().Subject;
        var validationProblemDetails = objectResult.Value.Should().BeOfType<ValidationProblemDetails>().Subject;
        validationProblemDetails.Errors.Should().BeEquivalentTo(_controller.ModelState);
    }

    [TestMethod]
    public void ValidationProblem_ProblemDetailsFactoryIsNull_CreatesValidationProblemDetailsManually()
    {
        // Arrange
        var modelStateDictionary = new ModelStateDictionary();
        modelStateDictionary.AddModelError("key", "error");

        // Act
        var result = _controller.ValidationProblem(modelStateDictionary: modelStateDictionary, statusCode: 400);

        // Assert
        var objectResult = result.Should().BeOfType<BadRequestObjectResult>().Subject;
        var validationProblemDetails = objectResult.Value.Should().BeOfType<ValidationProblemDetails>().Subject;
        validationProblemDetails.Errors["key"][0].Should().Be("error");
    }

    [TestMethod]
    public void ValidationProblem_ProblemDetailsFactoryIsNotNull_UsesProblemDetailsFactory()
    {
        // Arrange
        var modelStateDictionary = new ModelStateDictionary();
        modelStateDictionary.AddModelError("key", "error");

        var validationProblemDetails = new ValidationProblemDetails(modelStateDictionary)
        {
            Status = 400,
            Title = "Validation Error"
        };

        var stubProblemDetailsFactory = new StubProblemDetailsFactory(validationProblemDetails);
        _controller.ProblemDetailsFactory = stubProblemDetailsFactory;

        // Act
        var result = _controller.ValidationProblem(modelStateDictionary: modelStateDictionary);

        // Assert
        var objectResult = result.Should().BeOfType<BadRequestObjectResult>().Subject;
        var returnedProblemDetails = objectResult.Value.Should().BeOfType<ValidationProblemDetails>().Subject;
        returnedProblemDetails.Title.Should().Be("Validation Error");
    }

    [TestMethod]
    public void ValidationProblem_UsesProblemDetailsFactory()
    {
        // Arrange
        var modelStateDictionary = new ModelStateDictionary();
        modelStateDictionary.AddModelError("key", "error");

        var validationProblemDetails = new ValidationProblemDetails(modelStateDictionary)
        {
            Status = 400,
            Title = "Validation Error",
            Detail = "Some detail",
            Instance = "/test/instance"
        };

        var stubProblemDetailsFactory = new StubProblemDetailsFactory(validationProblemDetails);
        _controller.ProblemDetailsFactory = stubProblemDetailsFactory;

        // Act
        var result = _controller.ValidationProblem(modelStateDictionary: modelStateDictionary);

        // Assert
        var objectResult = result.Should().BeOfType<BadRequestObjectResult>().Subject;
        var returnedProblemDetails = objectResult.Value.Should().BeOfType<ValidationProblemDetails>().Subject;
        returnedProblemDetails.Title.Should().Be("Validation Error");
        returnedProblemDetails.Detail.Should().Be("Some detail");
        returnedProblemDetails.Instance.Should().Be("/test/instance");
        returnedProblemDetails.Status.Should().Be(400);
    }

    [TestMethod]
    public void ValidationProblem_ReturnsObjectResultWithCorrectStatusCode()
    {
        // Arrange
        var modelStateDictionary = new ModelStateDictionary();
        modelStateDictionary.AddModelError("key", "error");

        var validationProblemDetails = new ValidationProblemDetails(modelStateDictionary)
        {
            Status = 422,
            Title = "Validation Error"
        };

        var stubProblemDetailsFactory = new StubProblemDetailsFactory(validationProblemDetails);
        _controller.ProblemDetailsFactory = stubProblemDetailsFactory;

        // Act
        var result = _controller.ValidationProblem(modelStateDictionary: modelStateDictionary);

        // Assert
        var objectResult = result.Should().BeOfType<ObjectResult>().Subject;
        var returnedProblemDetails = objectResult.Value.Should().BeOfType<ValidationProblemDetails>().Subject;
        objectResult.StatusCode.Should().Be(422);
        returnedProblemDetails.Status.Should().Be(422);
    }

    [TestMethod]
    public void Problem_ShouldReturnObjectResult_WithExpectedType()
    {
        // Act
        var result = _controller.Problem("detail", "instance", 500, "title", "type");

        // Assert
        result.Should().BeOfType<ObjectResult>();
        result.StatusCode.Should().Be(500);
        var problemDetails = result.Value as ProblemDetails;
        problemDetails!.Type.Should().Be("https://epr-errors/type");
    }

    [TestMethod]
    public void Problem_WithException_ShouldReturnObjectResult_WithExpectedType()
    {
        // Arrange
        var exception = new Exception("error");

        // Act
        var result = _controller.Problem(exception);

        // Assert
        result.Should().BeOfType<ObjectResult>();
        result.StatusCode.Should().Be(500);
        var problemDetails = result.Value as ProblemDetails;
        problemDetails!.Type.Should().Be("https://epr-errors/exception");
        problemDetails.Title.Should().Be("Exception");
    }
}