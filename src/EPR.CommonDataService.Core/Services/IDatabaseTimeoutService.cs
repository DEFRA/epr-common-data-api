using Microsoft.EntityFrameworkCore;

namespace EPR.CommonDataService.Core.Services
{
    public interface IDatabaseTimeoutService
    {
        void SetCommandTimeout(DbContext context, int timeout);
    }
}
