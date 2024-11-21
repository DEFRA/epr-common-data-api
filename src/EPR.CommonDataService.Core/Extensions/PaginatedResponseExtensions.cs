using EPR.CommonDataService.Core.Models.Requests;
using EPR.CommonDataService.Core.Models.Response;
using System.Runtime;

namespace EPR.CommonDataService.Core.Extensions;

public static class PaginatedResponseExtensions
{
    public static PaginatedResponse<TOut> ToPaginatedResponse<T1, T2, TOut>(this IEnumerable<T1> rows, SubmissionsSummariesRequest<T2> request, int count) where TOut : class
    {
        return new PaginatedResponse<TOut>()
        {
            Items = rows.Cast<TOut>().ToList(),
            CurrentPage = request.PageNumber,
            PageSize = request.PageSize,
            TotalItems = count
        };
    }

    public static PaginatedResponse<TOut> ToCalculatedPaginatedResponse<T1,TOut>(this IEnumerable<T1> rows, IPaginatedRequest request, int count) where TOut : class
    {
        var items = rows.Select(x => x as TOut).ToList();
        var currentPage = Math.Max(1, request.PageNumber > ((int)Math.Ceiling(count / (double)request.PageSize)) ? 
                                               ((int)Math.Ceiling(count / (double)request.PageSize)) :
                                               Math.Max(1, request.PageNumber));
        
        return new PaginatedResponse<TOut>
        {
            Items = items,
            CurrentPage = currentPage,
            TotalItems = count,
            PageSize = request.PageSize
        };
    }
}