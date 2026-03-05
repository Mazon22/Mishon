namespace Mishon.Application.DTOs;

public class Result<T>
{
    public bool IsSuccess { get; }
    public T? Data { get; }
    public string? Error { get; }
    public ResultError? ResultError { get; }

    private Result(bool isSuccess, T? data, string? error, ResultError? resultError)
    {
        IsSuccess = isSuccess;
        Data = data;
        Error = error;
        ResultError = resultError;
    }

    public static Result<T> Success(T data) => new(true, data, null, null);
    public static Result<T> Failure(string error, ResultError? resultError = null) => new(false, default, error, resultError);
}

public class Result
{
    public bool IsSuccess { get; }
    public string? Error { get; }
    public ResultError? ResultError { get; }

    private Result(bool isSuccess, string? error, ResultError? resultError)
    {
        IsSuccess = isSuccess;
        Error = error;
        ResultError = resultError;
    }

    public static Result Success() => new(true, null, null);
    public static Result Failure(string error, ResultError? resultError = null) => new(false, error, resultError);
}

public enum ResultError
{
    NotFound,
    Conflict,
    Unauthorized,
    Forbidden,
    BadRequest,
    ValidationError,
    InternalError
}

public class PagedResult<T>
{
    public IEnumerable<T> Items { get; }
    public int Page { get; }
    public int PageSize { get; }
    public int TotalCount { get; }
    public int TotalPages => (int)Math.Ceiling(TotalCount / (double)PageSize);
    public bool HasPrevious => Page > 1;
    public bool HasNext => Page < TotalPages;

    public PagedResult(IEnumerable<T> items, int page, int pageSize, int totalCount)
    {
        Items = items;
        Page = page;
        PageSize = pageSize;
        TotalCount = totalCount;
    }
}
