using System.Net;
using System.Text.Json;

namespace Mishon.API.Middleware;

public class GlobalExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionHandlingMiddleware> _logger;

    public GlobalExceptionHandlingMiddleware(RequestDelegate next, ILogger<GlobalExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unhandled exception occurred at {Timestamp}", DateTime.UtcNow);
            await HandleExceptionAsync(context, ex);
        }
    }

    private static async Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        context.Response.ContentType = "application/json";

        var (statusCode, error, message) = exception switch
        {
            ArgumentException ex => (
                (int)HttpStatusCode.BadRequest,
                "Validation Error",
                ex.Message
            ),
            UnauthorizedAccessException ex => (
                (int)HttpStatusCode.Unauthorized,
                "Unauthorized",
                ex.Message
            ),
            KeyNotFoundException ex => (
                (int)HttpStatusCode.NotFound,
                "Not Found",
                ex.Message
            ),
            InvalidOperationException ex => (
                (int)HttpStatusCode.BadRequest,
                "Invalid Operation",
                ex.Message
            ),
            _ => (
                (int)HttpStatusCode.InternalServerError,
                "Internal Server Error",
                "Произошла внутренняя ошибка. Попробуйте позже."
            )
        };

        context.Response.StatusCode = statusCode;

        var response = new
        {
            error,
            message,
            statusCode,
            timestamp = DateTime.UtcNow
        };

        var options = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        };

        await context.Response.WriteAsync(JsonSerializer.Serialize(response, options));
    }
}

public static class GlobalExceptionHandlingMiddlewareExtensions
{
    public static IApplicationBuilder UseGlobalExceptionHandling(this IApplicationBuilder builder)
    {
        return builder.UseMiddleware<GlobalExceptionHandlingMiddleware>();
    }
}
