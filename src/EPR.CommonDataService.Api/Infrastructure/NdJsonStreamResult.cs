using System.Diagnostics;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Net.Http.Headers;

namespace EPR.CommonDataService.Api.Infrastructure;

public static class NdJsonStreamOptions
{
    public static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };
}

/// <summary>
///     An ActionResult that streams NDJSON (newline-delimited JSON) data from an async enumerable source.
/// </summary>
/// <typeparam name="T">The type of objects to serialize and stream.</typeparam>
public sealed class NdJsonStreamResult<T>
    : IActionResult
{
    private readonly IAsyncEnumerable<T> _dataSource;
    private readonly Action<Result>? _onComplete;

    /// <summary>
    ///     Initializes a new instance of the <see cref="NdJsonStreamResult{T}" /> class.
    /// </summary>
    /// <param name="dataSource">The async enumerable data source to stream.</param>
    /// <param name="onComplete">Optional callback invoked when streaming completes, providing result summary.</param>
    public NdJsonStreamResult(
        IAsyncEnumerable<T> dataSource,
        Action<Result>? onComplete = null)
    {
        _dataSource = dataSource ?? throw new ArgumentNullException(nameof(dataSource));
        _onComplete = onComplete;
    }

    /// <inheritdoc />
    public async Task ExecuteResultAsync(ActionContext context)
    {
        ArgumentNullException.ThrowIfNull(context);

        var response = context.HttpContext.Response;
        var ct = context.HttpContext.RequestAborted;

        long count = 0;
        var clientAborted = false;
        var sw = Stopwatch.StartNew();

        try
        {
            await using var enumerator = _dataSource
                .WithCancellation(ct)
                .GetAsyncEnumerator();

            // Force the underlying data source to execute before
            // we start writing the streaming response.
            if (!await enumerator.MoveNextAsync())
            {
                response.ContentType = "application/x-ndjson; charset=utf-8";
                response.Headers[HeaderNames.CacheControl] = "no-store";
                response.Headers["X-Accel-Buffering"] = "no";
                return;
            }

            response.ContentType = "application/x-ndjson; charset=utf-8";
            response.Headers[HeaderNames.CacheControl] = "no-store";
            response.Headers["X-Accel-Buffering"] = "no";

            await using var writer = new StreamWriter(
                response.Body,
                new UTF8Encoding(false),
                16 * 1024,
                true);

            writer.AutoFlush = false;

            do
            {
                var json = JsonSerializer.Serialize(
                    enumerator.Current,
                    NdJsonStreamOptions.JsonOptions);

                await writer.WriteAsync(json);
                await writer.WriteAsync('\n');
                await writer.FlushAsync(ct); // flush writer to response body
                await response.Body.FlushAsync(ct); // flush response body to the client

                count++;

            } while (await enumerator.MoveNextAsync());
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            clientAborted = true;
        }
        finally
        {
            sw.Stop();

            _onComplete?.Invoke(new Result
            {
                WasAbortedByClient = clientAborted,
                RecordsStreamed = count,
                Duration = sw.Elapsed
            });
        }
    }

    public record Result
    {
        public required bool WasAbortedByClient { get; init; }
        public required long RecordsStreamed { get; init; }
        public required TimeSpan Duration { get; init; }
    }
}
