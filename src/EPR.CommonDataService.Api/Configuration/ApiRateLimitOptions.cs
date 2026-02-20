using System.ComponentModel.DataAnnotations;
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Api.Configuration;

[ExcludeFromCodeCoverage]
[SuppressMessage("ReSharper", "CollectionNeverUpdated.Global")]
public sealed record ApiRateLimitOptions
{
    public const string ConfigSection = "ApiConfig:RateLimiting";
    public const string PayCalOrganisationsStreamPolicy = "GET /api/paycal/organisations/stream";
    public const string PayCalPomsStreamPolicy = "GET /api/paycal/poms/stream";

    /// <summary>
    ///     Allows the limiter to be disabled for all policies.
    /// </summary>
    public bool Enabled { get; init; } = true;

    public Dictionary<string, ConcurrentLimitPolicy> Policies { get; init; }
        = new(new PolicyNameComparer());

    public sealed record ConcurrentLimitPolicy
    {
        /// <summary>
        ///     Allows the limiter to be disabled on a per-policy basis.
        /// </summary>
        public bool Enabled { get; init; } = true;

        /// <summary>
        ///     Maximum number of permits that can be leased concurrently.
        /// </summary>
        [Range(1, int.MaxValue)]
        public int PermitLimit { get; init; } = 1;

        /// <summary>
        ///     Maximum number of permits that can be queued concurrently.
        /// </summary>
        [Range(0, int.MaxValue)]
        public int QueueLimit { get; init; } = 3;
    }

    /// <summary>
    ///     Handles any casing/trailing slash issues in input policy names.
    /// </summary>
    private sealed class PolicyNameComparer : IEqualityComparer<string>
    {
        public bool Equals(string? x, string? y)
        {
            return string.Equals(Canonical(x), Canonical(y), StringComparison.OrdinalIgnoreCase);
        }

        public int GetHashCode(string obj)
        {
            return StringComparer.OrdinalIgnoreCase.GetHashCode(Canonical(obj));
        }

        private static string Canonical(string? s)
        {
            return s?.Trim().TrimEnd('/') ?? string.Empty;
        }
    }
}