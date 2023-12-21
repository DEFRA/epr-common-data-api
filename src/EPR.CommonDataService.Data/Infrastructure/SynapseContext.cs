using System.Diagnostics.CodeAnalysis;
using EPR.CommonDataService.Data.Entities;
using Microsoft.EntityFrameworkCore;
using StringToGuidConverter = EPR.CommonDataService.Data.Converters.StringToGuidConverter;

namespace EPR.CommonDataService.Data.Infrastructure;

[ExcludeFromCodeCoverage]
public class SynapseContext : DbContext
{
    public DbSet<SubmissionEvent> SubmissionEvents { get; set; } = null!;
    public DbSet<PomSubmissionSummaryRow> SubmissionSummaries { get; set; } = null!;
    
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
            if (Database.ProviderName == "Microsoft.EntityFrameworkCore.InMemory")
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
            if (Database.ProviderName == "Microsoft.EntityFrameworkCore.InMemory")
            {
                entity.HasKey(e => e.FileId);
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
    }
    
    public virtual async Task<IList<TEntity>> RunSqlAsync<TEntity>(string sql, params object[] parameters) where TEntity : class
    {
        return await Set<TEntity>().FromSqlRaw(sql, parameters).AsAsyncEnumerable().ToListAsync();
    }
}
