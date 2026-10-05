namespace EPR.CommonDataService.Api.Features.Migration.RegistrationHistory;

public static class RegistrationHistorySql
{
    private const string ResourceName = "EPR.CommonDataService.Api.Features.Migration.RegistrationHistory.RegistrationHistory.sql";

    private static readonly Lazy<string> Sql = new(() =>
    {
        using var stream = typeof(RegistrationHistorySql).Assembly.GetManifestResourceStream(ResourceName)
            ?? throw new InvalidOperationException($"Embedded resource '{ResourceName}' not found.");
        using var reader = new StreamReader(stream);
        return reader.ReadToEnd();
    });

    public static string Load() => Sql.Value;
}
