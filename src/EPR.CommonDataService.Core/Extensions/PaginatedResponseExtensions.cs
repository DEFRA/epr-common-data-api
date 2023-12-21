using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Models.Response;
using EPR.CommonDataService.Data.Entities;

namespace EPR.CommonDataService.Core.Extensions;

public static class PaginatedResponseExtensions
{
    public static PaginatedResponse<PomSubmissionSummary> ToPaginatedResponse(this IEnumerable<PomSubmissionSummaryRow> rows, PomSubmissionsSummariesRequest request)
    {
        return new PaginatedResponse<PomSubmissionSummary>()
        {
            Items = rows.Select(x => x as PomSubmissionSummary).ToList(),
            CurrentPage = request.PageNumber,
            PageSize = request.PageSize,
            TotalItems = rows.FirstOrDefault()?.TotalItems ?? 0
        };
    }
}