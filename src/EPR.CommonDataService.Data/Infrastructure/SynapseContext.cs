using EPR.CommonDataService.Data.Converters;
using EPR.CommonDataService.Data.Entities;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.Collections.ObjectModel;
using System.Data;
using System.Data.Common;
using System.Diagnostics.CodeAnalysis;
using System.Reflection;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using IntToBoolConverter = EPR.CommonDataService.Data.Converters.IntToBoolConverter;
using StringToGuidConverter = EPR.CommonDataService.Data.Converters.StringToGuidConverter;
using StringToIntConverter = EPR.CommonDataService.Data.Converters.StringToIntConverter;

namespace EPR.CommonDataService.Data.Infrastructure;

[ExcludeFromCodeCoverage]
public class SynapseContext : DbContext
{
    public DbSet<SubmissionEvent> SubmissionEvents { get; set; } = null!;
    public DbSet<PomSubmissionSummaryRow> SubmissionSummaries { get; set; } = null!;
    public DbSet<RegistrationsSubmissionSummaryRow> RegistrationSummaries { get; set; } = null!;
    public DbSet<ApprovedSubmissionEntity> ApprovedSubmissions { get; set; } = null!;
    public DbSet<ApprovedSubmissionEntityOld> ApprovedSubmissionsOld { get; set; } = null!;
    public DbSet<OrganisationRegistrationSummaryDataRow> OrganisationRegistrationSummaries { get; set; } = null!;
    public DbSet<OrganisationRegistrationDetailsDto> OrganisationRegistrationSubmissionDetails { get; set; } = null!;
    public DbSet<RegistrationFeeCalculationDetailsModel> RegistrationFeeCalculationDetailsModel { get; set; } = null!;
    public DbSet<PayCalOrganisation> PayCalOrganisations { get; set; } = null!;
    public DbSet<PayCalPom> PayCalPoms { get; set; } = null!;

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
        var stringToIntConverter = StringToIntConverter.Get();

        modelBuilder.Entity<PayCalOrganisation>(entity =>
        {
            // Must have a key to allow inserts for unit tests
            if (Database.ProviderName == InMemoryProvider)
                entity.HasKey(e => new{e.SubmissionPeriodYear, e.OrganisationId});
            else
                entity.HasNoKey();

            entity.ToTable("t_producer_obligation_determination", schema: "dbo");
            entity.Property(e => e.OrganisationId).HasColumnName("organisation_id");
            entity.Property(e => e.SubsidiaryId).HasColumnName("subsidiary_id").HasMaxLength(4000);
            entity.Property(e => e.SubmitterId).HasColumnName("submitter_id").HasMaxLength(4000);
            entity.Property(e => e.OrganisationName).HasColumnName("organisation_name").HasMaxLength(4000);
            entity.Property(e => e.TradingName).HasColumnName("trading_name").HasMaxLength(4000);
            entity.Property(e => e.StatusCode).HasColumnName("status_code").HasMaxLength(4000);
            entity.Property(e => e.LeaverDate).HasColumnName("leaver_date").HasMaxLength(4000);
            entity.Property(e => e.JoinerDate).HasColumnName("joiner_date").HasMaxLength(4000);
            entity.Property(e => e.ObligationStatus).HasColumnName("obligation_status").HasMaxLength(1).IsFixedLength();
            entity.Property(e => e.NumDaysObligated).HasColumnName("num_days_obligated");
            entity.Property(e => e.ErrorCode).HasColumnName("error_code").HasMaxLength(4000);
            entity.Property(e => e.SubmissionPeriodYear).HasColumnName("submission_period_year");
        });

        modelBuilder.Entity<PayCalPom>(entity =>
        {
            // Must have a key to allow inserts for unit tests
            if (Database.ProviderName == InMemoryProvider)
                entity.HasKey(e => new{e.SubmissionPeriod, e.OrganisationId, e.PackagingType, e.PackagingMaterial});
            else
                entity.HasNoKey();

            entity.ToView("v_PayCal_Pom_MYC", schema: "dbo");
            entity.Property(e => e.OrganisationId).HasColumnName("organisation_id");
            entity.Property(e => e.SubsidiaryId).HasColumnName("subsidiary_id").HasMaxLength(4000);
            entity.Property(e => e.SubmitterId).HasColumnName("submitter_id").HasMaxLength(4000);
            entity.Property(e => e.SubmissionPeriod).HasColumnName("submission_period").HasMaxLength(4000);
            entity.Property(e => e.SubmissionPeriodDescription).HasColumnName("submission_period_desc").HasMaxLength(4000);
            entity.Property(e => e.PackagingActivity).HasColumnName("packaging_activity").HasMaxLength(4000);
            entity.Property(e => e.PackagingType).HasColumnName("packaging_type").HasMaxLength(4000);
            entity.Property(e => e.PackagingClass).HasColumnName("packaging_class").HasMaxLength(4000);
            entity.Property(e => e.PackagingMaterial).HasColumnName("packaging_material").HasMaxLength(4000);
            entity.Property(e => e.PackagingMaterialWeight).HasColumnName("packaging_material_weight");
        });

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
        modelBuilder.Entity<OrganisationRegistrationDetailsDto>()
            .Property(e => e.CompanyDetailsFileId)
            .HasConversion(stringToGuidConverter);
        modelBuilder.Entity<OrganisationRegistrationDetailsDto>()
            .Property(e => e.PartnershipFileId)
            .HasConversion(stringToGuidConverter);
        modelBuilder.Entity<OrganisationRegistrationDetailsDto>()
            .Property(e => e.BrandsFileId)
            .HasConversion(stringToGuidConverter);
        modelBuilder.Entity<OrganisationRegistrationDetailsDto>()
            .Property(e => e.IsComplianceScheme)
            .HasConversion(intToBoolConverter);
        modelBuilder.Entity<OrganisationRegistrationDetailsDto>()
            .Property(e => e.IsLateSubmission)
            .HasConversion(intToBoolConverter);
        modelBuilder.Entity<OrganisationRegistrationDetailsDto>()
            .Property(e => e.IsOnlineMarketPlace)
            .HasConversion(intToBoolConverter);
        modelBuilder.Entity<OrganisationRegistrationDetailsDto>()
            .Property(e => e.NationId)
            .HasConversion(stringToIntConverter);
        modelBuilder.Entity<OrganisationRegistrationDetailsDto>()
            .Property(e => e.NumberOfOnlineSubsidiaries)
            .HasConversion(stringToIntConverter);
        modelBuilder.Entity<OrganisationRegistrationDetailsDto>()
            .Property(e => e.NumberOfSubsidiaries)
            .HasConversion(stringToIntConverter);

        modelBuilder.Entity<RegistrationsSubmissionSummaryRow>()
            .Property(e => e.ComplianceSchemeId)
            .HasConversion(stringToGuidConverter);

        modelBuilder.Entity<PomSubmissionSummaryRow>()
            .Property(e => e.SubmissionId)
            .HasConversion(stringToGuidConverter);
    }

    private void BuildComplexEntities(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<RegistrationFeeCalculationDetailsModel>(entity => {
            entity.HasNoKey();
        });

        modelBuilder.Entity<UpdatedProducersResponseModel>(entity => {
            entity.HasNoKey();
        });

        modelBuilder.Entity<UpdatedProducersResponseModelV2>(entity => {
            entity.HasNoKey();
        });

        modelBuilder.Entity<SubmissionEvent>(AddSubmissionEventIdKeyIfApplicable);


        modelBuilder.Entity<PomSubmissionSummaryRow>(AddFileIdKeyIfApplicable);

        modelBuilder.Entity<RegistrationsSubmissionSummaryRow>(AddCompanyDetailsFileIdKeyIfApplicable);

        modelBuilder.Entity<ApprovedSubmissionEntity>(AddOrganisationIdKeyIfApplicable);

        modelBuilder.Entity<OrganisationRegistrationSummaryDataRow>(AddSubmissionIdKeyIfApplicable);

        modelBuilder.Entity<OrganisationRegistrationDetailsDto>(AddSubmissionIdKeyToDtoIfApplicable);
    }

    public virtual async Task<IList<TEntity>> RunSqlAsync<TEntity>(string sql, params object[] parameters) where TEntity : class
    {
        return await Set<TEntity>().FromSqlRaw(sql, parameters).AsAsyncEnumerable().ToListAsync();
    }

    public virtual async Task<IList<TEntity>> RunSpCommandAsync<TEntity>(string storedProcName, ILogger logger, string logPrefix, params SqlParameter[] parameters) where TEntity : new()
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

    private void AddSubmissionIdKeyToDtoIfApplicable(EntityTypeBuilder<OrganisationRegistrationDetailsDto> entity)
    {
        if (Database.ProviderName == InMemoryProvider)
        {
            entity.HasKey(e => e.SubmissionId);
        }
        else
        {
            entity.HasNoKey();
        }
    }

    private void AddSubmissionIdKeyIfApplicable(EntityTypeBuilder<OrganisationRegistrationSummaryDataRow> entity)
    {
        if (Database.ProviderName == InMemoryProvider)
        {
            entity.HasKey(e => e.SubmissionId);
        }
        else
        {
            entity.HasNoKey();
        }
    }

    private void AddOrganisationIdKeyIfApplicable(EntityTypeBuilder<ApprovedSubmissionEntity> entity)
    {
        if (Database.ProviderName == InMemoryProvider)
        {
            entity.HasKey(e => e.OrganisationId);
        }
        else
        {
            entity.HasNoKey();
        }
    }

    private void AddCompanyDetailsFileIdKeyIfApplicable(EntityTypeBuilder<RegistrationsSubmissionSummaryRow> entity)
    {
        if (Database.ProviderName == InMemoryProvider)
        {
            entity.HasKey(e => e.CompanyDetailsFileId);
        }
        else
        {
            entity.HasNoKey();
        }
    }

    private void AddFileIdKeyIfApplicable(EntityTypeBuilder<PomSubmissionSummaryRow> entity)
    {
        if (Database.ProviderName == InMemoryProvider)
        {
            entity.HasKey(e => e.FileId);
        }
        else
        {
            entity.HasNoKey();
        }
    }

    private void AddSubmissionEventIdKeyIfApplicable(EntityTypeBuilder<SubmissionEvent> entity)
    {
        if (Database.ProviderName == InMemoryProvider)
        {
            entity.HasKey(e => e.SubmissionEventId);
        }
        else
        {
            entity.HasNoKey();
        }
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