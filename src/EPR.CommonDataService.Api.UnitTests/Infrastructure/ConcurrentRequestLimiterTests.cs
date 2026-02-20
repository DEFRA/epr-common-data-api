using System.Diagnostics.CodeAnalysis;
using EPR.CommonDataService.Api.Infrastructure;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace EPR.CommonDataService.Api.UnitTests.Infrastructure;

[ExcludeFromCodeCoverage]
[TestClass]
public class ConcurrentRequestSemaphoreProviderTests
{
    [TestMethod]
    public void Get_ShouldReturnResourceKeyMatchingMethodAndPath()
    {
        // Arrange
        var config = BuildConfig(new Dictionary<string, string?>());
        var provider = new ConcurrentRequestSemaphoreProvider(config);
        var request = CreateRequest("GET", "/api/test");

        // Act
        var (resource, _) = provider.Get(request);

        // Assert
        resource.Should().Be("GET /api/test");
    }

    [TestMethod]
    public void Get_ShouldReturnSemaphoreWithDefaultConcurrencyOfOne()
    {
        // Arrange
        var config = BuildConfig(new Dictionary<string, string?>());
        var provider = new ConcurrentRequestSemaphoreProvider(config);
        var request = CreateRequest("GET", "/api/test");

        // Act
        var (_, semaphore) = provider.Get(request);

        // Assert
        semaphore.CurrentCount.Should().Be(1);
    }

    [TestMethod]
    public void Get_ShouldReturnSemaphoreWithConfiguredConcurrency()
    {
        // Arrange
        var config = BuildConfig(new Dictionary<string, string?>
        {
            { "GET /api/test", "5" }
        });
        var provider = new ConcurrentRequestSemaphoreProvider(config);
        var request = CreateRequest("GET", "/api/test");

        // Act
        var (_, semaphore) = provider.Get(request);

        // Assert
        semaphore.CurrentCount.Should().Be(5);
    }

    [TestMethod]
    public void Get_WithInvalidConfigValue_ShouldFallBackToDefaultOfOne()
    {
        // Arrange
        var config = BuildConfig(new Dictionary<string, string?>
        {
            { "GET /api/test", "not-a-number" }
        });
        var provider = new ConcurrentRequestSemaphoreProvider(config);
        var request = CreateRequest("GET", "/api/test");

        // Act
        var (_, semaphore) = provider.Get(request);

        // Assert
        semaphore.CurrentCount.Should().Be(1);
    }

    [TestMethod]
    public void Get_ShouldReturnSameSemaphoreForSameResource()
    {
        // Arrange
        var config = BuildConfig(new Dictionary<string, string?>());
        var provider = new ConcurrentRequestSemaphoreProvider(config);

        // Act
        var (_, semaphore1) = provider.Get(CreateRequest("GET", "/api/test"));
        var (_, semaphore2) = provider.Get(CreateRequest("GET", "/api/test"));

        // Assert
        semaphore1.Should().BeSameAs(semaphore2);
    }

    [TestMethod]
    public void Get_ShouldReturnDifferentSemaphoresForDifferentPaths()
    {
        // Arrange
        var config = BuildConfig(new Dictionary<string, string?>());
        var provider = new ConcurrentRequestSemaphoreProvider(config);

        // Act
        var (_, semaphore1) = provider.Get(CreateRequest("GET", "/api/one"));
        var (_, semaphore2) = provider.Get(CreateRequest("GET", "/api/two"));

        // Assert
        semaphore1.Should().NotBeSameAs(semaphore2);
    }

    [TestMethod]
    public void Get_ShouldReturnDifferentSemaphoresForDifferentMethods()
    {
        // Arrange
        var config = BuildConfig(new Dictionary<string, string?>());
        var provider = new ConcurrentRequestSemaphoreProvider(config);

        // Act
        var (_, semaphore1) = provider.Get(CreateRequest("GET", "/api/test"));
        var (_, semaphore2) = provider.Get(CreateRequest("POST", "/api/test"));

        // Assert
        semaphore1.Should().NotBeSameAs(semaphore2);
    }

    private static IConfiguration BuildConfig(Dictionary<string, string?> values)
    {
        return new ConfigurationBuilder()
            .AddInMemoryCollection(values)
            .Build();
    }

    private static HttpRequest CreateRequest(string method, string path)
    {
        var context = new DefaultHttpContext();
        context.Request.Method = method;
        context.Request.Path = path;
        return context.Request;
    }
}

[ExcludeFromCodeCoverage]
[TestClass]
public class ConcurrentRequestLimiterTests
{
    private Mock<ILogger<ConcurrentRequestLimiter>> _loggerMock = null!;
    private ConcurrentRequestSemaphoreProvider _semaphoreProvider = null!;
    private ConcurrentRequestLimiter _limiter = null!;

    [TestInitialize]
    public void TestInitialize()
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>())
            .Build();

        _loggerMock = new Mock<ILogger<ConcurrentRequestLimiter>>();
        _semaphoreProvider = new ConcurrentRequestSemaphoreProvider(config);
        _limiter = new ConcurrentRequestLimiter(_semaphoreProvider, _loggerMock.Object);
    }

    [TestMethod]
    public async Task OnResourceExecutionAsync_WhenSemaphoreAvailable_ShouldCallNext()
    {
        // Arrange
        var context = CreateResourceExecutingContext("GET", "/api/test");
        var nextCalled = false;

        // Act
        await _limiter.OnResourceExecutionAsync(context, () =>
        {
            nextCalled = true;
            return Task.FromResult<ResourceExecutedContext>(null!);
        });

        // Assert
        nextCalled.Should().BeTrue();
        context.Result.Should().BeNull();
    }

    [TestMethod]
    public async Task OnResourceExecutionAsync_WhenSemaphoreExhausted_ShouldReturn429()
    {
        // Arrange
        var context = CreateResourceExecutingContext("GET", "/api/test");

        // Exhaust the semaphore (default concurrency = 1)
        var (_, semaphore) = _semaphoreProvider.Get(context.HttpContext.Request);
        await semaphore.WaitAsync();

        // Act
        await _limiter.OnResourceExecutionAsync(context, () =>
            Task.FromResult<ResourceExecutedContext>(null!));

        // Assert
        context.Result.Should().BeOfType<StatusCodeResult>()
            .Which.StatusCode.Should().Be(StatusCodes.Status429TooManyRequests);

        semaphore.Release();
    }

    [TestMethod]
    public async Task OnResourceExecutionAsync_WhenSemaphoreExhausted_ShouldNotCallNext()
    {
        // Arrange
        var context = CreateResourceExecutingContext("GET", "/api/test");
        var nextCalled = false;

        var (_, semaphore) = _semaphoreProvider.Get(context.HttpContext.Request);
        await semaphore.WaitAsync();

        // Act
        await _limiter.OnResourceExecutionAsync(context, () =>
        {
            nextCalled = true;
            return Task.FromResult<ResourceExecutedContext>(null!);
        });

        // Assert
        nextCalled.Should().BeFalse();

        semaphore.Release();
    }

    [TestMethod]
    public async Task OnResourceExecutionAsync_WhenSemaphoreExhausted_ShouldLogWarning()
    {
        // Arrange
        var context = CreateResourceExecutingContext("GET", "/api/test");

        var (_, semaphore) = _semaphoreProvider.Get(context.HttpContext.Request);
        await semaphore.WaitAsync();

        // Act
        await _limiter.OnResourceExecutionAsync(context, () =>
            Task.FromResult<ResourceExecutedContext>(null!));

        // Assert
        _loggerMock.Verify(
            x => x.Log(
                LogLevel.Warning,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, _) => v.ToString()!.Contains("concurrency limit")),
                null,
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);

        semaphore.Release();
    }

    [TestMethod]
    public async Task OnResourceExecutionAsync_ShouldReleaseSemaphoreAfterNextCompletes()
    {
        // Arrange
        var context = CreateResourceExecutingContext("GET", "/api/test");
        var (_, semaphore) = _semaphoreProvider.Get(context.HttpContext.Request);

        // Act
        await _limiter.OnResourceExecutionAsync(context, () =>
            Task.FromResult<ResourceExecutedContext>(null!));

        // Assert — semaphore should be released back to 1
        semaphore.CurrentCount.Should().Be(1);
    }

    [TestMethod]
    public async Task OnResourceExecutionAsync_WhenNextThrows_ShouldStillReleaseSemaphore()
    {
        // Arrange
        var context = CreateResourceExecutingContext("GET", "/api/test");
        var (_, semaphore) = _semaphoreProvider.Get(context.HttpContext.Request);

        // Act
        var act = () => _limiter.OnResourceExecutionAsync(context, () =>
            throw new InvalidOperationException("boom"));

        // Assert
        await act.Should().ThrowAsync<InvalidOperationException>();
        semaphore.CurrentCount.Should().Be(1);
    }

    [TestMethod]
    public async Task OnResourceExecutionAsync_ConcurrentRequests_ShouldRejectSecondRequest()
    {
        // Arrange
        var context1 = CreateResourceExecutingContext("GET", "/api/test");
        var context2 = CreateResourceExecutingContext("GET", "/api/test");
        var tcs = new TaskCompletionSource<ResourceExecutedContext>();

        // Start first request (holds the semaphore)
        var firstRequest = _limiter.OnResourceExecutionAsync(context1, () => tcs.Task);

        // Act — second request should be rejected
        await _limiter.OnResourceExecutionAsync(context2, () =>
            Task.FromResult<ResourceExecutedContext>(null!));

        // Assert
        context2.Result.Should().BeOfType<StatusCodeResult>()
            .Which.StatusCode.Should().Be(StatusCodes.Status429TooManyRequests);

        // Cleanup
        tcs.SetResult(null!);
        await firstRequest;
    }

    [TestMethod]
    public async Task OnResourceExecutionAsync_DifferentResources_ShouldNotInterfere()
    {
        // Arrange
        var context1 = CreateResourceExecutingContext("GET", "/api/one");
        var context2 = CreateResourceExecutingContext("GET", "/api/two");
        var tcs = new TaskCompletionSource<ResourceExecutedContext>();

        // Hold the semaphore for /api/one
        var firstRequest = _limiter.OnResourceExecutionAsync(context1, () => tcs.Task);

        var nextCalled = false;

        // Act — /api/two should still proceed
        await _limiter.OnResourceExecutionAsync(context2, () =>
        {
            nextCalled = true;
            return Task.FromResult<ResourceExecutedContext>(null!);
        });

        // Assert
        nextCalled.Should().BeTrue();
        context2.Result.Should().BeNull();

        // Cleanup
        tcs.SetResult(null!);
        await firstRequest;
    }

    private static ResourceExecutingContext CreateResourceExecutingContext(string method, string path)
    {
        var httpContext = new DefaultHttpContext();
        httpContext.Request.Method = method;
        httpContext.Request.Path = path;

        var actionContext = new ActionContext(httpContext, new Microsoft.AspNetCore.Routing.RouteData(), new Microsoft.AspNetCore.Mvc.Abstractions.ActionDescriptor());
        return new ResourceExecutingContext(actionContext, new List<IFilterMetadata>(), new List<IValueProviderFactory>());
    }
}
