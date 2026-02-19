using System.Data.Common;
using System.Diagnostics.CodeAnalysis;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace EPR.CommonDataService.Data.Infrastructure;

/// <summary>
///     Intercepts database commands. If the command text contains a matching comment, it will override the timeout for
///     that command.
/// </summary>
[ExcludeFromCodeCoverage]
public sealed class TimeoutInterceptor : DbCommandInterceptor
{
    public const string Trigger = "Use timeout: ";
    private static readonly Regex Pattern = new(@$"^{Regex.Escape($"-- {Trigger}")}(\d+)", RegexOptions.Compiled);

    public override InterceptionResult<DbDataReader> ReaderExecuting(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<DbDataReader> result)
    {
        ManipulateCommand(command);
        return result;
    }

    public override ValueTask<InterceptionResult<DbDataReader>> ReaderExecutingAsync(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<DbDataReader> result,
        CancellationToken cancellationToken = default)
    {
        ManipulateCommand(command);
        return new ValueTask<InterceptionResult<DbDataReader>>(result);
    }

    private static void ManipulateCommand(DbCommand command)
    {
        var match = Pattern.Match(command.CommandText);

        if (match.Success)
        {
            var timeout = int.Parse(match.Groups[1].Value);
            command.CommandTimeout = timeout;
        }
    }
}

public static class TimeoutInterceptorExtensions
{
    /// <summary>
    ///     Tags the IQueryable to be intercepted by <see cref="TimeoutInterceptor" />, effectively setting the
    ///     underlying command timeout period to the specified value.
    /// </summary>
    /// <typeparam name="TEntity">The type of entity being queried.</typeparam>
    /// <param name="source">The source query.</param>
    /// <param name="timeout">Timeout (will be rounded to seconds).</param>
    /// <returns>A new query which is tagged to have a longer timeout applied.</returns>
    public static IQueryable<TEntity> WithTimeout<TEntity>(this IQueryable<TEntity> source, TimeSpan timeout)
    {
        return source.TagWith($"{TimeoutInterceptor.Trigger}{timeout.TotalSeconds:0}");
    }
}