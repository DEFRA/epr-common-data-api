using EPR.CommonDataService.Data.Entities;
using Microsoft.EntityFrameworkCore;
using System.Diagnostics.CodeAnalysis;
using StringToGuidConverter = EPR.CommonDataService.Data.Converters.StringToGuidConverter;
using IntToBoolConverter = EPR.CommonDataService.Data.Converters.IntToBoolConverter;
namespace EPR.CommonDataService.Data.Infrastructure;

[ExcludeFromCodeCoverage]
public class SynapseContext : DbContext
{
    public DbSet<SubmissionEvent> SubmissionEvents { get; set; } = null!;
    public DbSet<ProducerDetailsModel> ProducerDetailsModel { get; set; } = null!;
    public DbSet<PomSubmissionSummaryRow> SubmissionSummaries { get; set; } = null!;
    public DbSet<RegistrationsSubmissionSummaryRow> RegistrationSummaries { get; set; } = null!;
    public DbSet<ApprovedSubmissionEntity> ApprovedSubmissions { get; set; } = null!;

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
        modelBuilder.Entity<ProducerDetailsModel>(entity => {
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

        modelBuilder.Entity<ProducerDetailsModel>(entity =>
        {
            entity.HasNoKey();
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

        modelBuilder.Entity<ProducerDetailsModel>()
            .Property(e => e.IsOnlineMarketplace)
            .HasConversion(intToBoolConverter);
    }

    public virtual async Task<IList<TEntity>> RunSqlAsync<TEntity>(string sql, params object[] parameters) where TEntity : class
    {
        return await Set<TEntity>().FromSqlRaw(sql, parameters).AsAsyncEnumerable().ToListAsync();
    }
}
