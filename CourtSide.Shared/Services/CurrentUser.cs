using System.Security.Claims;
using CourtSide.Shared.Constants;
using Microsoft.AspNetCore.Http;

namespace CourtSide.Shared.Services;

/// <summary>Exposes the currently authenticated user, read from the JWT (never from route/body).</summary>
public interface ICurrentUser
{
    int? UserId { get; }
    string? Username { get; }
    bool IsAdmin { get; }
    bool IsAuthenticated { get; }

    /// The <c>jti</c> claim of the token this request was made with.
    string? TokenId { get; }

    /// When that token stops being valid on its own.
    DateTime? TokenExpiresAt { get; }
}

public class CurrentUser : ICurrentUser
{
    private readonly IHttpContextAccessor _accessor;

    public CurrentUser(IHttpContextAccessor accessor) => _accessor = accessor;

    private ClaimsPrincipal? Principal => _accessor.HttpContext?.User;

    public bool IsAuthenticated => Principal?.Identity?.IsAuthenticated ?? false;

    public int? UserId
    {
        get
        {
            var value = Principal?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            return int.TryParse(value, out var id) ? id : null;
        }
    }

    public string? Username => Principal?.FindFirst(ClaimTypes.Name)?.Value;

    public bool IsAdmin => Principal?.IsInRole(Roles.Admin) ?? false;

    public string? TokenId => Principal?.FindFirst("jti")?.Value;

    public DateTime? TokenExpiresAt
    {
        get
        {
            var value = Principal?.FindFirst("exp")?.Value;
            return long.TryParse(value, out var seconds)
                ? DateTimeOffset.FromUnixTimeSeconds(seconds).UtcDateTime
                : null;
        }
    }
}
