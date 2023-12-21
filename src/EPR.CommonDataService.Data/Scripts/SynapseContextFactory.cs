using EPR.CommonDataService.Data.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace EPR.CommonDataService.Data;

public class SynapseContextFactory : IDesignTimeDbContextFactory<SynapseContext>
{
    public SynapseContext CreateDbContext(string[] args)
    {
        var optionsBuilder = new DbContextOptionsBuilder<SynapseContext>();

        optionsBuilder.UseSqlServer(args.Length > 0 ? args[0] : "-");

        return new SynapseContext(optionsBuilder.Options);
    }
}
