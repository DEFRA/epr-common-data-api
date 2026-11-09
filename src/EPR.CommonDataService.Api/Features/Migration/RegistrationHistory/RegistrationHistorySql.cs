using System.Text.RegularExpressions;

namespace EPR.CommonDataService.Api.Features.Migration.RegistrationHistory;

public static partial class RegistrationHistorySql
{
    public const string BlobContainerNamePlaceholder = "__BLOB_CONTAINER_NAME__";

    private const string ResourceName = "EPR.CommonDataService.Api.Features.Migration.RegistrationHistory.RegistrationHistory.sql";

    private static readonly Lazy<string> Sql = new(() =>
    {
        using var stream = typeof(RegistrationHistorySql).Assembly.GetManifestResourceStream(ResourceName)
            ?? throw new InvalidOperationException($"Embedded resource '{ResourceName}' not found.");
        using var reader = new StreamReader(stream);
        return reader.ReadToEnd();
    });

    public static string Load() => Sql.Value;

    /// <summary>
    /// Loads the script with the blob container name substituted in. A DbParameter was not visible to
    /// the batch's statements in Synapse, so the name is inlined; it is restricted to valid
    /// Azure container names (lowercase letters, digits, hyphens) so it cannot break out of the literal.
    /// </summary>
    public static string Load(string blobContainerName)
    {
        if (string.IsNullOrWhiteSpace(blobContainerName) || !ContainerNameRegex().IsMatch(blobContainerName))
            throw new InvalidOperationException($"Blob container name '{blobContainerName}' is not a valid Azure container name.");

        return Sql.Value.Replace(BlobContainerNamePlaceholder, blobContainerName, StringComparison.Ordinal);
    }

    [GeneratedRegex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$")]
    private static partial Regex ContainerNameRegex();
}
