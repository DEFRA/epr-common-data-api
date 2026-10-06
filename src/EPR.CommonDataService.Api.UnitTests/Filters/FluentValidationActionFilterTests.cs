using EPR.CommonDataService.Api.Infrastructure;
using FluentValidation;
using FluentValidation.Results;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;
using MsOptions = Microsoft.Extensions.Options.Options;

namespace EPR.CommonDataService.Api.UnitTests.Filters;

[TestClass]
public class FluentValidationActionFilterTests
{
    private Mock<IServiceProvider> serviceProvider = null!;
    private FluentValidationActionFilter filter = null!;

    [TestInitialize]
    public void TestInitialize()
    {
        serviceProvider = new Mock<IServiceProvider>();

        var apiBehaviorOptions = MsOptions.Create(new ApiBehaviorOptions
        {
            // Mirrors the default [ApiController] factory: 400 + ValidationProblemDetails.
            InvalidModelStateResponseFactory = ctx =>
                new BadRequestObjectResult(new ValidationProblemDetails(ctx.ModelState)),
        });

        filter = new FluentValidationActionFilter(serviceProvider.Object, apiBehaviorOptions);
    }

    // --- helpers ---

    private static ActionExecutingContext MakeContext(IDictionary<string, object?> arguments)
    {
        var httpContext = new DefaultHttpContext();
        var actionContext = new ActionContext(httpContext, new RouteData(), new ActionDescriptor());
        return new ActionExecutingContext(
            actionContext,
            filters: [],
            actionArguments: arguments,
            controller: new object());
    }

    private void RegisterValidator<T>(IValidator<T> validator)
    {
        // GetService uses the open generic at runtime; the filter resolves IValidator<T> by type.
        serviceProvider
            .Setup(sp => sp.GetService(typeof(IValidator<T>)))
            .Returns(validator);
    }

    private static ActionExecutionDelegate NoOpNext()
    {
        return () =>
        {
            return Task.FromResult(new ActionExecutedContext(
                new ActionContext(new DefaultHttpContext(), new RouteData(), new ActionDescriptor()),
                filters: [],
                controller: new object()));
        };
    }

    // --- tests ---

    [TestMethod]
    public async Task OnActionExecutionAsync_CallsNext_WhenNoValidatorIsRegistered()
    {
        // Arrange — no IValidator<string> registered, so GetService returns null
        serviceProvider.Setup(sp => sp.GetService(It.IsAny<Type>())).Returns((object?)null);
        var context = MakeContext(new Dictionary<string, object?> { ["arg"] = "some value" });
        var nextCalled = false;
        ActionExecutionDelegate next = () =>
        {
            nextCalled = true;
            return Task.FromResult(new ActionExecutedContext(context, [], new object()));
        };

        // Act
        await filter.OnActionExecutionAsync(context, next);

        // Assert — pipeline must not be short-circuited when there is nothing to validate
        nextCalled.ShouldBeTrue();
        context.Result.ShouldBeNull();
    }

    [TestMethod]
    public async Task OnActionExecutionAsync_CallsNext_WhenValidationPasses()
    {
        // Arrange
        var dto = new SampleDto { Name = "valid" };
        var validator = new Mock<IValidator<SampleDto>>();
        validator
            .Setup(v => v.ValidateAsync(It.IsAny<ValidationContext<object>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult());
        RegisterValidator(validator.Object);

        var context = MakeContext(new Dictionary<string, object?> { ["dto"] = dto });
        var nextCalled = false;
        ActionExecutionDelegate next = () =>
        {
            nextCalled = true;
            return Task.FromResult(new ActionExecutedContext(context, [], new object()));
        };

        // Act
        await filter.OnActionExecutionAsync(context, next);

        // Assert
        nextCalled.ShouldBeTrue();
        context.Result.ShouldBeNull();
    }

    [TestMethod]
    public async Task OnActionExecutionAsync_ShortCircuitsWithBadRequest_WhenValidationFails()
    {
        // Arrange
        var dto = new SampleDto { Name = "" };
        var failures = new List<ValidationFailure>
        {
            new("Name", "Name is required."),
        };
        var validator = new Mock<IValidator<SampleDto>>();
        validator
            .Setup(v => v.ValidateAsync(It.IsAny<ValidationContext<object>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult(failures));
        RegisterValidator(validator.Object);

        var context = MakeContext(new Dictionary<string, object?> { ["dto"] = dto });

        // Act
        await filter.OnActionExecutionAsync(context, NoOpNext());

        // Assert — pipeline short-circuited; result must be the factory's 400
        var result = context.Result.ShouldBeOfType<BadRequestObjectResult>();
        var problem = result.Value.ShouldBeOfType<ValidationProblemDetails>();
        problem.Errors.ShouldContainKey("Name");
        problem.Errors["Name"].ShouldContain("Name is required.");
    }

    [TestMethod]
    public async Task OnActionExecutionAsync_DoesNotCallNext_WhenValidationFails()
    {
        // Arrange
        var dto = new SampleDto { Name = "" };
        var validator = new Mock<IValidator<SampleDto>>();
        validator
            .Setup(v => v.ValidateAsync(It.IsAny<ValidationContext<object>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult(new[] { new ValidationFailure("Name", "Required.") }));
        RegisterValidator(validator.Object);

        var context = MakeContext(new Dictionary<string, object?> { ["dto"] = dto });
        var nextCalled = false;
        ActionExecutionDelegate next = () =>
        {
            nextCalled = true;
            return Task.FromResult(new ActionExecutedContext(context, [], new object()));
        };

        // Act
        await filter.OnActionExecutionAsync(context, next);

        // Assert
        nextCalled.ShouldBeFalse();
    }

    [TestMethod]
    public async Task OnActionExecutionAsync_SkipsNullArguments()
    {
        // Arrange — null model bindings are legitimate (optional params); should not throw
        var context = MakeContext(new Dictionary<string, object?> { ["dto"] = null });
        var nextCalled = false;
        ActionExecutionDelegate next = () =>
        {
            nextCalled = true;
            return Task.FromResult(new ActionExecutedContext(context, [], new object()));
        };

        // Act
        await filter.OnActionExecutionAsync(context, next);

        // Assert
        nextCalled.ShouldBeTrue();
    }

    [TestMethod]
    public async Task OnActionExecutionAsync_AccumulatesErrorsAcrossMultipleArguments()
    {
        // Arrange — two invalid arguments; both sets of errors must appear in ModelState
        var dto1 = new SampleDto { Name = "" };
        var dto2 = new AnotherDto { Value = -1 };

        var validator1 = new Mock<IValidator<SampleDto>>();
        validator1
            .Setup(v => v.ValidateAsync(It.IsAny<ValidationContext<object>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult(new[] { new ValidationFailure("Name", "Name is required.") }));

        var validator2 = new Mock<IValidator<AnotherDto>>();
        validator2
            .Setup(v => v.ValidateAsync(It.IsAny<ValidationContext<object>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ValidationResult(new[] { new ValidationFailure("Value", "Value must be positive.") }));

        RegisterValidator(validator1.Object);
        RegisterValidator(validator2.Object);

        var context = MakeContext(new Dictionary<string, object?>
        {
            ["dto1"] = dto1,
            ["dto2"] = dto2,
        });

        // Act
        await filter.OnActionExecutionAsync(context, NoOpNext());

        // Assert — errors from both arguments land in the same problem details
        var result = context.Result.ShouldBeOfType<BadRequestObjectResult>();
        var problem = result.Value.ShouldBeOfType<ValidationProblemDetails>();
        problem.Errors.ShouldContainKey("Name");
        problem.Errors.ShouldContainKey("Value");
    }

    [TestMethod]
    public async Task OnActionExecutionAsync_PassesCancellationToken_FromHttpContext()
    {
        // Arrange
        using var cts = new CancellationTokenSource();
        var dto = new SampleDto { Name = "ok" };

        var validator = new Mock<IValidator<SampleDto>>();
        validator
            .Setup(v => v.ValidateAsync(It.IsAny<ValidationContext<object>>(), cts.Token))
            .ReturnsAsync(new ValidationResult());
        RegisterValidator(validator.Object);

        var httpContext = new DefaultHttpContext { RequestAborted = cts.Token };
        var actionContext = new ActionContext(httpContext, new RouteData(), new ActionDescriptor());
        var context = new ActionExecutingContext(
            actionContext,
            filters: [],
            actionArguments: new Dictionary<string, object?> { ["dto"] = dto },
            controller: new object());

        // Act
        await filter.OnActionExecutionAsync(context, NoOpNext());

        // Assert — the specific overload accepting the request's token must be called
        validator.Verify(
            v => v.ValidateAsync(It.IsAny<ValidationContext<object>>(), cts.Token),
            Times.Once);
    }

}

// Minimal DTOs used only as test fixtures; Castle.DynamicProxy requires non-private types to proxy IValidator<T>.
public record SampleDto { public string Name { get; init; } = ""; }
public record AnotherDto { public int Value { get; init; } }
