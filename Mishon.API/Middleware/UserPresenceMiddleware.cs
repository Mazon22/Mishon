using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using Mishon.Infrastructure.Data;

namespace Mishon.API.Middleware;

public class UserPresenceMiddleware
{
    private readonly RequestDelegate _next;

    public UserPresenceMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context, MishonDbContext dbContext)
    {
        if (context.User.Identity?.IsAuthenticated == true)
        {
            var userIdValue = context.User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (int.TryParse(userIdValue, out var userId))
            {
                var now = DateTime.UtcNow;
                var user = await dbContext.Users.FirstOrDefaultAsync(u => u.Id == userId);
                if (user != null && user.LastSeenAt < now.AddMinutes(-1))
                {
                    user.LastSeenAt = now;
                    await dbContext.SaveChangesAsync();
                }
            }
        }

        await _next(context);
    }
}
