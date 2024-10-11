using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Models.Response;

namespace EPR.CommonDataService.Core.Extensions;

public static class PaginatedResponseExtensions
{
    public static PaginatedResponse<TOut> ToPaginatedResponse<T1,T2,TOut>(this IEnumerable<T1> rows, SubmissionsSummariesRequest<T2> request, int count) where TOut : class
    {
        return new PaginatedResponse<TOut>()
        {
            Items = rows.Cast<TOut>().ToList(),
            CurrentPage = request.PageNumber,
            PageSize = request.PageSize,
            TotalItems = count
        };
    }
}