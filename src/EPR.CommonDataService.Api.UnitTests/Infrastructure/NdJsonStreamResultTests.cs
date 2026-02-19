using System.Diagnostics.CodeAnalysis;
using System.Text;
using EPR.CommonDataService.Api.Infrastructure;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Net.Http.Headers;

namespace EPR.CommonDataService.Api.UnitTests.Infrastructure;

[ExcludeFromCodeCoverage]
[TestClass]
public class NdJsonStreamResultTests
{
    private DefaultHttpContext _httpContext = null!;
    private ActionContext _actionContext = null!;
    private MemoryStream _responseBody = null!;

    [TestInitialize]
    public void TestInitialize()
    {
        _responseBody = new MemoryStream();
        _httpContext = new DefaultHttpContext
        {
            Response =
            {
                Body = _responseBody
            }
        };
        _actionContext = new ActionContext
        {
            HttpContext = _httpContext
        };
    }

    [TestCleanup]
    public void TestCleanup()
    {
        _responseBody.Dispose();
    }

    [TestMethod]
    public async Task ExecuteResultAsync_ShouldSetCorrectContentType()
    {
        // Arrange
        static async IAsyncEnumerable<TestRecord> GetRecords()
        {
            await Task.CompletedTask;
            yield break;
        }

        var result = new NdJsonStreamResult<TestRecord>(GetRecords());

        // Act
        await result.ExecuteResultAsync(_actionContext);

        // Assert
        _httpContext.Response.ContentType.Should().Be("application/x-ndjson; charset=utf-8");
    }

    [TestMethod]
    public async Task ExecuteResultAsync_ShouldSetCacheControlHeader()
    {
        // Arrange
        static async IAsyncEnumerable<TestRecord> GetRecords()
        {
            await Task.CompletedTask;
            yield break;
        }

        var result = new NdJsonStreamResult<TestRecord>(GetRecords());

        // Act
        await result.ExecuteResultAsync(_actionContext);

        // Assert
        _httpContext.Response.Headers[HeaderNames.CacheControl].ToString().Should().Be("no-store");
    }

    [TestMethod]
    public async Task ExecuteResultAsync_ShouldSetAccelBufferingHeader()
    {
        // Arrange
        static async IAsyncEnumerable<TestRecord> GetRecords()
        {
            await Task.CompletedTask;
            yield break;
        }

        var result = new NdJsonStreamResult<TestRecord>(GetRecords());

        // Act
        await result.ExecuteResultAsync(_actionContext);

        // Assert
        _httpContext.Response.Headers["X-Accel-Buffering"].ToString().Should().Be("no");
    }

    [TestMethod]
    public async Task ExecuteResultAsync_WithEmptyEnumerable_ShouldInvokeCallbackWithZeroCount()
    {
        // Arrange
        static async IAsyncEnumerable<TestRecord> GetRecords()
        {
            await Task.CompletedTask;
            yield break;
        }

        long callbackCount = -1;
        TimeSpan callbackDuration = TimeSpan.Zero;
        var result = new NdJsonStreamResult<TestRecord>(GetRecords(), r =>
        {
            callbackCount = r.RecordsStreamed;
            callbackDuration = r.Duration;
        });

        // Act
        await result.ExecuteResultAsync(_actionContext);

        // Assert
        callbackCount.Should().Be(0);
        callbackDuration.Should().BeGreaterOrEqualTo(TimeSpan.Zero);
    }

    [TestMethod]
    public async Task ExecuteResultAsync_WithSingleRecord_ShouldInvokeCallbackWithCountOfOne()
    {
        // Arrange
        static async IAsyncEnumerable<TestRecord> GetRecords()
        {
            await Task.CompletedTask;
            yield return new TestRecord { Id = 1, Name = "Test" };
        }

        long callbackCount = -1;
        var result = new NdJsonStreamResult<TestRecord>(GetRecords(), r =>
        {
            callbackCount = r.RecordsStreamed;
        });

        // Act
        await result.ExecuteResultAsync(_actionContext);

        // Assert
        callbackCount.Should().Be(1);
    }

    [TestMethod]
    public async Task ExecuteResultAsync_WithMultipleRecords_ShouldInvokeCallbackWithCorrectCount()
    {
        // Arrange
        static async IAsyncEnumerable<TestRecord> GetRecords()
        {
            await Task.CompletedTask;
            yield return new TestRecord { Id = 1, Name = "First" };
            yield return new TestRecord { Id = 2, Name = "Second" };
            yield return new TestRecord { Id = 3, Name = "Third" };
        }

        long callbackCount = -1;
        var result = new NdJsonStreamResult<TestRecord>(GetRecords(), r =>
        {
            callbackCount = r.RecordsStreamed;
        });

        // Act
        await result.ExecuteResultAsync(_actionContext);

        // Assert
        callbackCount.Should().Be(3);
    }

    [TestMethod]
    public async Task ExecuteResultAsync_ShouldSerializeRecordsAsNewlineDelimitedJson()
    {
        // Arrange
        static async IAsyncEnumerable<TestRecord> GetRecords()
        {
            await Task.CompletedTask;
            yield return new TestRecord { Id = 1, Name = "First" };
            yield return new TestRecord { Id = 2, Name = "Second" };
        }

        var result = new NdJsonStreamResult<TestRecord>(GetRecords());

        // Act
        await result.ExecuteResultAsync(_actionContext);

        // Assert
        _responseBody.Position = 0;
        var content = Encoding.UTF8.GetString(_responseBody.ToArray());
        var lines = content.Split('\n', StringSplitOptions.RemoveEmptyEntries);

        lines.Should().HaveCount(2);
        lines[0].Should().Be("{\"id\":1,\"name\":\"First\"}");
        lines[1].Should().Be("{\"id\":2,\"name\":\"Second\"}");
    }

    [TestMethod]
    public async Task ExecuteResultAsync_ShouldUseCamelCasePropertyNames()
    {
        // Arrange
        static async IAsyncEnumerable<TestRecordWithPascalCase> GetRecords()
        {
            await Task.CompletedTask;
            yield return new TestRecordWithPascalCase { RecordId = 1, FullName = "Test" };
        }

        var result = new NdJsonStreamResult<TestRecordWithPascalCase>(GetRecords());

        // Act
        await result.ExecuteResultAsync(_actionContext);

        // Assert
        _responseBody.Position = 0;
        var content = Encoding.UTF8.GetString(_responseBody.ToArray());

        content.Should().Contain("\"recordId\":1");
        content.Should().Contain("\"fullName\":\"Test\"");
    }

    [TestMethod]
    public async Task ExecuteResultAsync_ShouldIgnoreNullValues()
    {
        // Arrange
        static async IAsyncEnumerable<TestRecord> GetRecords()
        {
            await Task.CompletedTask;
            yield return new TestRecord { Id = 1, Name = null };
        }

        var result = new NdJsonStreamResult<TestRecord>(GetRecords());

        // Act
        await result.ExecuteResultAsync(_actionContext);

        // Assert
        _responseBody.Position = 0;
        var content = Encoding.UTF8.GetString(_responseBody.ToArray());

        content.Should().NotContain("name");
        content.Trim().Should().Be("{\"id\":1}");
    }

    [TestMethod]
    public async Task ExecuteResultAsync_ShouldInvokeCallbackWithDuration()
    {
        // Arrange
        static async IAsyncEnumerable<TestRecord> GetRecords()
        {
            await Task.Delay(10);
            yield return new TestRecord { Id = 1, Name = "Test" };
        }

        TimeSpan callbackDuration = TimeSpan.Zero;
        var result = new NdJsonStreamResult<TestRecord>(GetRecords(), r =>
        {
            callbackDuration = r.Duration;
        });

        // Act
        await result.ExecuteResultAsync(_actionContext);

        // Assert
        callbackDuration.Should().BeGreaterThan(TimeSpan.Zero);
    }

    [TestMethod]
    public async Task ExecuteResultAsync_WithCancellation_ShouldStopProcessing()
    {
        // Arrange
        var cts = new CancellationTokenSource();
        var recordsYielded = 0;

        async IAsyncEnumerable<TestRecord> GetRecords()
        {
            for (var i = 0; i < 100; i++)
            {
                await Task.Delay(10, cts.Token);
                recordsYielded++;
                yield return new TestRecord { Id = i, Name = $"Record{i}" };

                if (i == 2)
                {
                    // ReSharper disable once AccessToDisposedClosure
                    await cts.CancelAsync();
                }
            }
        }

        var result = new NdJsonStreamResult<TestRecord>(GetRecords());
        _httpContext.RequestAborted = cts.Token;

        // Act
        await result.ExecuteResultAsync(_actionContext);

        // Assert
        recordsYielded.Should().BeLessThan(100);
        cts.Dispose();
    }

    [TestMethod]
    public async Task ExecuteResultAsync_WithCancellation_ShouldReportAbortedInResult()
    {
        // Arrange
        var cts = new CancellationTokenSource();
        NdJsonStreamResult<TestRecord>.Result? callbackResult = null;

        async IAsyncEnumerable<TestRecord> GetRecords()
        {
            yield return new TestRecord { Id = 1, Name = "First" };
            yield return new TestRecord { Id = 2, Name = "Second" };
            await cts.CancelAsync();
            await Task.Delay(10, cts.Token); // will throw
            yield return new TestRecord { Id = 3, Name = "Third" };
        }

        var result = new NdJsonStreamResult<TestRecord>(
            GetRecords(),
            r => callbackResult = r);
        _httpContext.RequestAborted = cts.Token;

        // Act
        await result.ExecuteResultAsync(_actionContext);

        // Assert
        callbackResult.Should().NotBeNull();
        callbackResult!.WasAbortedByClient.Should().BeTrue();
        callbackResult.RecordsStreamed.Should().Be(2);
        callbackResult.Duration.Should().BeGreaterOrEqualTo(TimeSpan.Zero);
        cts.Dispose();
    }

    [TestMethod]
    public async Task ExecuteResultAsync_WithError_ShouldInvokeCallbackThenThrow()
    {
        // Arrange
        NdJsonStreamResult<TestRecord>.Result? callbackResult = null;

        static async IAsyncEnumerable<TestRecord> GetRecords()
        {
            await Task.CompletedTask;
            yield return new TestRecord { Id = 1, Name = "First" };
            yield return new TestRecord { Id = 2, Name = "Second" };
            throw new InvalidOperationException("Simulated DB failure");
        }

        var result = new NdJsonStreamResult<TestRecord>(
            GetRecords(),
            r => callbackResult = r);

        // Act & Assert
        await Assert.ThrowsExceptionAsync<InvalidOperationException>(
            () => result.ExecuteResultAsync(_actionContext));

        callbackResult.Should().NotBeNull();
        callbackResult!.WasAbortedByClient.Should().BeFalse();
        callbackResult.RecordsStreamed.Should().Be(2);
        callbackResult.Duration.Should().BeGreaterOrEqualTo(TimeSpan.Zero);
    }

    [TestMethod]
    public async Task ExecuteResultAsync_WithErrorOnFirstRecord_ShouldReportZeroCount()
    {
        // Arrange
        NdJsonStreamResult<TestRecord>.Result? callbackResult = null;

        static async IAsyncEnumerable<TestRecord> GetRecords()
        {
            yield return await Task.FromException<TestRecord>(new InvalidOperationException("immediate failure"));
        }

        var result = new NdJsonStreamResult<TestRecord>(
            GetRecords(),
            r => callbackResult = r);

        // Act & Assert
        await Assert.ThrowsExceptionAsync<InvalidOperationException>(
            () => result.ExecuteResultAsync(_actionContext));

        callbackResult.Should().NotBeNull();
        callbackResult!.RecordsStreamed.Should().Be(0);
    }

    [TestMethod]
    public async Task ExecuteResultAsync_WhenSuccessful_ShouldReportNotAborted()
    {
        // Arrange
        NdJsonStreamResult<TestRecord>.Result? callbackResult = null;

        static async IAsyncEnumerable<TestRecord> GetRecords()
        {
            await Task.CompletedTask;
            yield return new TestRecord { Id = 1, Name = "Test" };
        }

        var result = new NdJsonStreamResult<TestRecord>(
            GetRecords(),
            r => callbackResult = r);

        // Act
        await result.ExecuteResultAsync(_actionContext);

        // Assert
        callbackResult.Should().NotBeNull();
        callbackResult!.WasAbortedByClient.Should().BeFalse();
        callbackResult.RecordsStreamed.Should().Be(1);
    }

    [TestMethod]
    public async Task ExecuteResultAsync_ShouldEndEachLineWithNewline()
    {
        // Arrange
        static async IAsyncEnumerable<TestRecord> GetRecords()
        {
            await Task.CompletedTask;
            yield return new TestRecord { Id = 1, Name = "Test" };
        }

        var result = new NdJsonStreamResult<TestRecord>(GetRecords());

        // Act
        await result.ExecuteResultAsync(_actionContext);

        // Assert
        _responseBody.Position = 0;
        var content = Encoding.UTF8.GetString(_responseBody.ToArray());

        content.Should().EndWith("\n");
    }

    [TestMethod]
    public void Constructor_WithNullDataSource_ShouldThrowArgumentNullException()
    {
        // Act & Assert
        var act = () => new NdJsonStreamResult<TestRecord>(null!);
        
        act.Should().Throw<ArgumentNullException>()
            .WithParameterName("dataSource");
    }

    [TestMethod]
    public async Task ExecuteResultAsync_WithNullActionContext_ShouldThrowArgumentNullException()
    {
        // Arrange
        static async IAsyncEnumerable<TestRecord> GetRecords()
        {
            await Task.CompletedTask;
            yield break;
        }

        var result = new NdJsonStreamResult<TestRecord>(GetRecords());

        // Act & Assert
        await Assert.ThrowsExceptionAsync<ArgumentNullException>(async () =>
            await result.ExecuteResultAsync(null!));
    }

    [TestMethod]
    public async Task ExecuteResultAsync_WithNoCallback_ShouldCompleteSuccessfully()
    {
        // Arrange
        static async IAsyncEnumerable<TestRecord> GetRecords()
        {
            await Task.CompletedTask;
            yield return new TestRecord { Id = 1, Name = "Test" };
        }

        var result = new NdJsonStreamResult<TestRecord>(GetRecords(), onComplete: null);

        // Act
        await result.ExecuteResultAsync(_actionContext);

        // Assert
        _responseBody.Position = 0;
        var content = Encoding.UTF8.GetString(_responseBody.ToArray());
        content.Should().Contain("\"id\":1");
    }

    private class TestRecord
    {
        public int Id { get; set; }
        public string? Name { get; set; }
    }

    private class TestRecordWithPascalCase
    {
        public int RecordId { get; set; }
        public string? FullName { get; set; }
    }
}