using Microsoft.EntityFrameworkCore;
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Core.Services
{
    [ExcludeFromCodeCoverage]
    public class DatabaseTimeoutService : IDatabaseTimeoutService
    {
        public void SetCommandTimeout(DbContext context, int timeout)
        {
            context.Database.SetCommandTimeout(timeout);
        }
    }
}
