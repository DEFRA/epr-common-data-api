namespace EPR.CommonDataService.Core.Models.Requests;

public interface IPaginatedRequest
{
    public int PageSize { get; set; }

    public int PageNumber { get; set; }
}
