using System.Collections.Concurrent;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace EPR.CommonDataService.Api.Infrastructure;

/// <summary>
///     Provides semaphores for concurrent request limiting.
///     Semaphores are scoped to be per endpoint (HTTP Method + Path).
///     Default concurrency limit is 1.
/// </summary>
/// <remarks>
///     Concurrency limit can be overridden via config:
///     "GET /api/path/endpoint": 2
/// </remarks>
public sealed class ConcurrentRequestSemaphoreProvider(IConfiguration configuration)
{
    private readonly ConcurrentDictionary<string, SemaphoreSlim> _semaphores = new();

    public (string, SemaphoreSlim) Get(HttpRequest request)
    {
        var resource = $"{request.Method.ToUpperInvariant()} {request.Path.ToString().ToLowerInvariant()}";
        var semaphore = _semaphores.GetOrAdd(resource, _ => new SemaphoreSlim(GetMaxConcurrency()));
        return (resource, semaphore);

        int GetMaxConcurrency()
        {
            var raw = configuration[resource];
            return int.TryParse(raw, out var i) ? i : 1;
        }
    }
}

/// <summary>
///     Resource filter that limits the number of concurrent requests allowed per resource.
///     Requests that cannot be served immediately are rejected with HTTP 429.
/// </summary>
/// <remarks>
///     This is a global limit, not per-client.
/// </remarks>
public sealed class ConcurrentRequestLimiter(
    ConcurrentRequestSemaphoreProvider semaphoreProvider,
    ILogger<ConcurrentRequestLimiter> logger)
    : IAsyncResourceFilter
{
    public async Task OnResourceExecutionAsync(ResourceExecutingContext context, ResourceExecutionDelegate next)
    {
        var (resource, semaphore) = semaphoreProvider.Get(context.HttpContext.Request);

        if (!await semaphore.WaitAsync(0))
        {
            logger.LogWarning("Request rejected due to concurrency limit. Resource={Resource}", resource);

            context.Result = new StatusCodeResult(StatusCodes.Status429TooManyRequests);
            return;
        }

        try
        {
            await next();
        }
        finally
        {
            semaphore.Release();
        }
    }
}