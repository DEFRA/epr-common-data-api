using EPR.CommonDataService.Data.Entities;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.Collections.ObjectModel;
using System.Data;
using System.Data.Common;
using System.Diagnostics;
using System.Diagnostics.CodeAnalysis;
using System.Reflection;
using StringToGuidConverter = EPR.CommonDataService.Data.Converters.StringToGuidConverter;
using IntToBoolConverter = EPR.CommonDataService.Data.Converters.IntToBoolConverter;
namespace EPR.CommonDataService.Data.Infrastructure;

[ExcludeFromCodeCoverage]
public class SynapseContext : DbContext
{
    public DbSet<SubmissionEvent> SubmissionEvents { get; set; } = null!;
    public DbSet<ProducerDetailsModel> ProducerDetailsModel { get; set; } = null!;
    public DbSet<CsoMemberDetailsModel> CsoMemberDetailsModel { get; set; } = null;
    public DbSet<PomSubmissionSummaryRow> SubmissionSummaries { get; set; } = null!;
    public DbSet<RegistrationsSubmissionSummaryRow> RegistrationSummaries { get; set; } = null!;
    public DbSet<ApprovedSubmissionEntity> ApprovedSubmissions { get; set; } = null!;
    public DbSet<OrganisationRegistrationSummaryDataRow> OrganisationRegistrationSummaries { get; set; } = null!;
    public DbSet<OrganisationRegistrationDetailsDto> OrganisationRegistrationSubmissionDetails { get; set; } = null!;

    private const string InMemoryProvider = "Microsoft.EntityFrameworkCore.InMemory";

    public SynapseContext(DbContextOptions<SynapseContext> options)
        : base(options)
    {
    }

    public SynapseContext()
    {
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        BuildComplexEntities(modelBuilder);

        var stringToGuidConverter = StringToGuidConverter.Get();
        var intToBoolConverter = IntToBoolConverter.Get();

        modelBuilder.Entity<PomSubmissionSummaryRow>()
            .Property(e => e.SubmissionId)
            .HasConversion(stringToGuidConverter);

        modelBuilder.Entity<PomSubmissionSummaryRow>()
            .Property(e => e.OrganisationId)
            .HasConversion(stringToGuidConverter);

        modelBuilder.Entity<PomSubmissionSummaryRow>()
            .Property(e => e.FileId)
            .HasConversion(stringToGuidConverter);

        modelBuilder.Entity<PomSubmissionSummaryRow>()
            .Property(e => e.UserId)
            .HasConversion(stringToGuidConverter);

        modelBuilder.Entity<PomSubmissionSummaryRow>()
            .Property(e => e.ComplianceSchemeId)
            .HasConversion(stringToGuidConverter);

        modelBuilder.Entity<RegistrationsSubmissionSummaryRow>()
            .Property(e => e.SubmissionId)
            .HasConversion(stringToGuidConverter);

        modelBuilder.Entity<RegistrationsSubmissionSummaryRow>()
            .Property(e => e.OrganisationId)
            .HasConversion(stringToGuidConverter);

        modelBuilder.Entity<RegistrationsSubmissionSummaryRow>()
            .Property(e => e.CompanyDetailsFileId)
            .HasConversion(stringToGuidConverter);

        modelBuilder.Entity<RegistrationsSubmissionSummaryRow>()
            .Property(e => e.BrandsFileId)
            .HasConversion(stringToGuidConverter);

        modelBuilder.Entity<RegistrationsSubmissionSummaryRow>()
            .Property(e => e.PartnershipFileId)
            .HasConversion(stringToGuidConverter);

        modelBuilder.Entity<RegistrationsSubmissionSummaryRow>()
            .Property(e => e.UserId)
            .HasConversion(stringToGuidConverter);

        modelBuilder.Entity<RegistrationsSubmissionSummaryRow>()
            .Property(e => e.ComplianceSchemeId)
            .HasConversion(stringToGuidConverter);

        modelBuilder.Entity<OrganisationRegistrationSummaryDataRow>()
            .Property(e => e.SubmissionId)
            .HasConversion(stringToGuidConverter);
        modelBuilder.Entity<OrganisationRegistrationSummaryDataRow>()
            .Property(e => e.OrganisationId)
            .HasConversion(stringToGuidConverter);
        modelBuilder.Entity<OrganisationRegistrationSummaryDataRow>()
            .Property(e => e.RegulatorUserId)
            .HasConversion(stringToGuidConverter);

        modelBuilder.Entity<OrganisationRegistrationDetailsDto>()
            .Property(e => e.SubmissionId)
            .HasConversion(stringToGuidConverter);
        modelBuilder.Entity<OrganisationRegistrationDetailsDto>()
            .Property(e => e.OrganisationId)
            .HasConversion(stringToGuidConverter);
        modelBuilder.Entity<OrganisationRegistrationDetailsDto>()
            .Property(e => e.RegulatorUserId)
            .HasConversion(stringToGuidConverter);
        modelBuilder.Entity<OrganisationRegistrationDetailsDto>()
            .Property(e => e.SubmittedUserId)
            .HasConversion(stringToGuidConverter);

        modelBuilder.Entity<RegistrationsSubmissionSummaryRow>()
            .Property(e => e.ComplianceSchemeId)
            .HasConversion(stringToGuidConverter);

        modelBuilder.Entity<ProducerDetailsModel>()
            .Property(e => e.IsOnlineMarketplace)
            .HasConversion(intToBoolConverter);
        modelBuilder.Entity<CsoMemberDetailsModel>()
            .Property(e => e.IsOnlineMarketplace)
            .HasConversion(intToBoolConverter);
    }

    private void BuildComplexEntities(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<ProducerDetailsModel>(entity => {
            entity.HasNoKey();
        });
        
        modelBuilder.Entity<CsoMemberDetailsModel>(entity => {
            entity.HasNoKey();
        });
        
        modelBuilder.Entity<SubmissionEvent>(entity =>
        {
            if (Database.ProviderName == InMemoryProvider)
            {
                entity.HasKey(e => e.SubmissionEventId);
            }
            else
            {
                entity.HasNoKey();
            }
        });


        modelBuilder.Entity<PomSubmissionSummaryRow>(entity =>
        {
            if (Database.ProviderName == InMemoryProvider)
            {
                entity.HasKey(e => e.FileId);
            }
            else
            {
                entity.HasNoKey();
            }
        });

        modelBuilder.Entity<RegistrationsSubmissionSummaryRow>(entity =>
        {
            if (Database.ProviderName == InMemoryProvider)
            {
                entity.HasKey(e => e.CompanyDetailsFileId);
            }
            else
            {
                entity.HasNoKey();
            }
        });

        modelBuilder.Entity<ApprovedSubmissionEntity>(entity =>
        {
            if (Database.ProviderName == InMemoryProvider)
            {
                entity.HasKey(e => e.OrganisationId);
            }
            else
            {
                entity.HasNoKey();
            }
        });

        modelBuilder.Entity<OrganisationRegistrationSummaryDataRow>(entity =>
        {
            if (Database.ProviderName == InMemoryProvider)
            {
                entity.HasKey(e => e.SubmissionId);
            }
            else
            {
                entity.HasNoKey();
            }
        });

        modelBuilder.Entity<OrganisationRegistrationDetailsDto>(entity =>
        {
            if (Database.ProviderName == InMemoryProvider)
            {
                entity.HasKey(e => e.SubmissionId);
            }
            else
            {
                entity.HasNoKey();
            }
        });
    }

    public virtual async Task<IList<TEntity>> RunSqlAsync<TEntity>(string sql, params object[] parameters) where TEntity : class
    {
        return await Set<TEntity>().FromSqlRaw(sql, parameters).AsAsyncEnumerable().ToListAsync();
    }

    public virtual async Task<IList<TEntity>> RunSPCommandAsync<TEntity>(string storedProcName, ILogger logger, string logPrefix, params SqlParameter[] parameters) where TEntity : new()
    {
        DbConnection connection = Database.GetDbConnection();

        try
        {
            if (connection.State != ConnectionState.Open)
                await connection.OpenAsync();

            if (connection.State == ConnectionState.Open)
            {
                var command = CreateCommand(connection, storedProcName, parameters);
                command.CommandTimeout = Database.GetCommandTimeout() ?? 120;

                var readerResult = await command.ExecuteReaderAsync();
                var result = await PopulateDto<TEntity>(readerResult, logger, logPrefix);

                await readerResult.DisposeAsync();
                await command.DisposeAsync();
                return result;
            }
        }
        finally
        {
            if (connection.State == ConnectionState.Open)
            {
                await connection.CloseAsync();
            }
        }
        return [];
    }

    private static async Task<IList<T>> PopulateDto<T>(DbDataReader reader, ILogger logger, string logPrefix) where T : new()
    {
        List<T> list = [];

        ReadOnlyCollection<DbColumn> schemaColumns = await reader.GetColumnSchemaAsync();

        while (await reader.ReadAsync())
        {
            var instance = new T();

            foreach (var prop in typeof(T).GetProperties(BindingFlags.Public | BindingFlags.Instance))
            {
                var columnMeta = schemaColumns
                 .FirstOrDefault(col => string.Equals(col.ColumnName, prop.Name, StringComparison.OrdinalIgnoreCase));

                if (columnMeta == null)
                {
                    continue;
                }

                var dataType = columnMeta.DataType;

                var ordinal = reader.GetOrdinal(prop.Name);
                if (await reader.IsDBNullAsync(ordinal))
                {
                    continue;
                }
                var value = reader.GetValue(ordinal);

                try
                {
                    SetProperty<T>( instance, prop, value, dataType, logger, logPrefix);
                }
                catch ( Exception ex)
                {
                    logger.LogError(ex, "{Logprefix}: SubmissionsService - Property assignment of {TypeName}.{PropertyName}, of type  '{PropertyType}' assignment failed with DB value '{Value}' of type {DataType}.", logPrefix, nameof(T), prop.Name, prop.PropertyType.Name, value, dataType);
                }
            }

            list.Add(instance);
        }

        return list;
    }

    private static void SetProperty<T>(T instance, PropertyInfo prop, object value, Type dataType, ILogger logger, string logPrefix)
    {
        try
        {
            if (IsGuidConversion(dataType, prop.PropertyType))
            {
                AssignGuidValue(instance, prop, value);
            }
            else if (IsStringToString(dataType, prop.PropertyType))
            {
                prop.SetValue(instance, value.ToString());
            }
            else if (IsNumericConversion(dataType, prop.PropertyType))
            {
                prop.SetValue(instance, Convert.ChangeType(value, prop.PropertyType));
            }
            else if (IsDateTimeConversion(dataType, prop.PropertyType))
            {
                prop.SetValue(instance, Convert.ToDateTime(value));
            }
            else
            {
                prop.SetValue(instance, value);
            }
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "{Logprefix}: SubmissionsService - Property assignment of {TypeName}.{PropertyName}, of type '{PropertyType}' assignment failed with DB value '{Value}' of type {DataType}.",
                logPrefix, nameof(T), prop.Name, prop.PropertyType.Name, value, dataType);
        }
    }

    private static bool IsGuidConversion(Type dataType, Type propType) =>
        dataType == typeof(string) && (propType == typeof(Guid) || propType == typeof(Guid?)) ||
        dataType == typeof(Guid) && propType == typeof(Guid);

    private static void AssignGuidValue(object instance, PropertyInfo prop, object value)
    {
        if (prop.PropertyType == typeof(Guid?))
        {
            if (Guid.TryParse(value.ToString(), out Guid guid))
                prop.SetValue(instance, guid);
        }
        else
        {
            prop.SetValue(instance, Guid.Parse(value.ToString()));
        }
    }

    private static bool IsStringToString(Type dataType, Type propType) =>
        dataType == typeof(string) && propType == typeof(string);

    private static bool IsNumericConversion(Type dataType, Type propType) =>
        dataType == typeof(int) && propType == typeof(int);

    private static bool IsDateTimeConversion(Type dataType, Type propType) =>
        (dataType == typeof(string) || dataType == typeof(DateTime)) &&
        (propType == typeof(DateTime) || propType == typeof(DateTime?));

    private static DbCommand CreateCommand(DbConnection connection, string sql, params SqlParameter[] parameters)
    {
        var command = connection.CreateCommand();
        command.CommandText = sql;
        command.CommandType = CommandType.StoredProcedure;
        foreach (var parameter in parameters)
        {
            command.Parameters.Add(parameter);
        }

        return command;
    }
}

[ExcludeFromCodeCoverage]
public static class DbDataReaderExtensions
{
    public static bool HasColumn(this DbDataReader reader, string columnName)
    {
        for (var i = 0; i < reader.FieldCount; i++)
        {
            if (reader.GetName(i).Equals(columnName, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }
        return false;
    }
}
