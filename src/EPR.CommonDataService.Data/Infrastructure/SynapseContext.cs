using EPR.CommonDataService.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using System.Diagnostics.CodeAnalysis;
using StringToGuidConverter = EPR.CommonDataService.Data.Converters.StringToGuidConverter;
using StringToIntConverter = EPR.CommonDataService.Data.Converters.StringToIntConverter;
using StringToDateConverter = EPR.CommonDataService.Data.Converters.StringToDateConverter;
using Microsoft.Data.SqlClient;
using System.Data.Common;
using System.Data;
using static Microsoft.EntityFrameworkCore.DbLoggerCategory.Database;
using System.Reflection;
using System.Diagnostics;


namespace EPR.CommonDataService.Data.Infrastructure;

[ExcludeFromCodeCoverage]
public class SynapseContext : DbContext
{
    public DbSet<SubmissionEvent> SubmissionEvents { get; set; } = null!;
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

        var stringToGuidConverter = StringToGuidConverter.Get();

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
    }

    public virtual async Task<IList<TEntity>> RunSqlAsync<TEntity>(string sql, params object[] parameters) where TEntity : class
    {
        return await Set<TEntity>().FromSqlRaw(sql, parameters).AsAsyncEnumerable().ToListAsync();
    }

    public async Task<IList<TEntity>> RunSPCommand<TEntity>(string storedProcName, params SqlParameter[] parameters) where TEntity : new()
    {
        DbConnection connection = Database.GetDbConnection();

        try
        {
            if (connection.State != ConnectionState.Open)
                await connection.OpenAsync();

            if (connection.State == ConnectionState.Open)
            {
                var command = CreateCommand(connection, storedProcName, parameters);
                var readerResult = await command.ExecuteReaderAsync();
                var result = await PopulateDto<TEntity>(readerResult);

                await readerResult.DisposeAsync();
                await command.DisposeAsync();
                return result;
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine(ex);
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

    private static async Task<IList<T>> PopulateDto<T>(DbDataReader reader) where T : new()
    {
        List<T> list = [];

        while (await reader.ReadAsync())
        {
            var instance = new T();

            foreach (var prop in typeof(T).GetProperties(BindingFlags.Public | BindingFlags.Instance))
            {
                if (!reader.HasColumn(prop.Name) || await reader.IsDBNullAsync(reader.GetOrdinal(prop.Name)))
                {
                    continue;
                }

                var value = reader.GetValue(reader.GetOrdinal(prop.Name));
                prop.SetValue(instance, value);
            }

            list.Add(instance);
        }

        return list;
    }

    private DbCommand CreateCommand(DbConnection connection, string sql, params SqlParameter[] parameters)
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
