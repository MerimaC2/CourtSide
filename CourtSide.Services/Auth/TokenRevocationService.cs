using CourtSide.Core.Entities;
using CourtSide.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace CourtSide.Services.Auth;

public interface ITokenRevocationService
{
    Task RevokeAsync(string tokenId, int userId, DateTime expiresAt);
    Task<bool> IsRevokedAsync(string tokenId, CancellationToken cancellationToken = default);
}

/// <summary>
/// Keeps track of access tokens that were signed out. A JWT stays valid until it expires,
/// so logging out has to be recorded here for the API to start rejecting it.
/// </summary>
public class TokenRevocationService : ITokenRevocationService
{
    private readonly DatabaseContext _db;

    public TokenRevocationService(DatabaseContext db) => _db = db;

    public async Task RevokeAsync(string tokenId, int userId, DateTime expiresAt)
    {
        if (await _db.RevokedTokens.AnyAsync(t => t.TokenId == tokenId)) return;

        _db.RevokedTokens.Add(new RevokedToken
        {
            TokenId = tokenId,
            UserId = userId,
            ExpiresAt = expiresAt,
            CreatedAt = DateTime.UtcNow
        });

        // Entries are only useful until the token would have expired anyway.
        var cutoff = DateTime.UtcNow;
        await _db.RevokedTokens.Where(t => t.ExpiresAt < cutoff).ExecuteDeleteAsync();
        await _db.SaveChangesAsync();
    }

    public Task<bool> IsRevokedAsync(string tokenId, CancellationToken cancellationToken = default) =>
        _db.RevokedTokens.AsNoTracking().AnyAsync(t => t.TokenId == tokenId, cancellationToken);
}
