using EPR.CommonDataService.Api.Configuration;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.Extensions.Options;

namespace EPR.CommonDataService.Api.UnitTests.Controllers;

[TestClass]
public class ApiControllerBaseTests
{
    private readonly ApiControllerBase _controller;

    public ApiControllerBaseTests()
    {
        var apiConfig = new ApiConfig { BaseProblemTypePath = "https://epr-errors/" };
        var mockApiConfigOptions = new Mock<IOptions<ApiConfig>>();
        mockApiConfigOptions.Setup(o => o.Value).Returns(apiConfig);
        _controller = new ApiControllerBase(mockApiConfigOptions.Object)
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