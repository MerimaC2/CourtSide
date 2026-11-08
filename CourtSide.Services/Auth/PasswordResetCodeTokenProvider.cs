using System.Security.Cryptography;
using CourtSide.Core.Entities;
using CourtSide.Core.Entities.Identity;
using CourtSide.Infrastructure;
using CourtSide.Shared.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace CourtSide.Services.Auth;

/// <summary>
/// Identity's password-reset token, issued as a six-digit code that can be typed in from an email.
/// Only the code's hash is stored (<see cref="PasswordResetCode"/>). A code is valid for
/// <see cref="Lifetime"/>, is spent by its first correct use or by too many wrong ones, and issuing
/// a new code spends every earlier one, so only the newest email works.
/// </summary>
public class PasswordResetCodeTokenProvider : IUserTwoFactorTokenProvider<ApplicationUser>
{
    public const string ProviderName = "PasswordResetCode";

    /// <summary>How long an emailed reset code stays valid — long enough to switch to a mail
    /// client and back, short enough that an old message is not a standing key to the account.</summary>
    public static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(15);

    /// <summary>Wrong guesses allowed against one emailed code before it is spent.</summary>
    private const int MaxAttempts = 5;

    private readonly DatabaseContext _db;
    private readonly IAppClock _clock;

    public PasswordResetCodeTokenProvider(DatabaseContext db, IAppClock clock)
    {
        _db = db;
        _clock = clock;
    }

    public async Task<string> GenerateAsync(string purpose, UserManager<ApplicationUser> manager, ApplicationUser user)
    {
        var now = _clock.UtcNow;
        var pending = await _db.PasswordResetCodes
            .Where(c => c.UserId == user.Id && c.UsedAt == null && c.ExpiresAt > now)
            .ToListAsync();
        foreach (var code in pending)
            code.UsedAt = now;

        var plainCode = GenerateCode();
        _db.PasswordResetCodes.Add(new PasswordResetCode
        {
            UserId = user.Id,
            CodeHash = manager.PasswordHasher.HashPassword(user, plainCode),
            ExpiresAt = now.Add(Lifetime),
            CreatedAt = now
        });
        await _db.SaveChangesAsync();

        return plainCode;
    }

    public async Task<bool> ValidateAsync(string purpose, string token, UserManager<ApplicationUser> manager, ApplicationUser user)
    {
        var now = _clock.UtcNow;
        var candidate = await _db.PasswordResetCodes
            .Where(c => c.UserId == user.Id && c.UsedAt == null && c.ExpiresAt > now)
            .OrderByDescending(c => c.Id)
            .FirstOrDefaultAsync();
        if (candidate is null) return false;

        var verified = manager.PasswordHasher.VerifyHashedPassword(user, candidate.CodeHash, token)
            != PasswordVerificationResult.Failed;

        if (!verified)
        {
            // A six-digit code is a million guesses, so misses are limited: a handful of them
            // spends the code and a new email is needed.
            // Counted in the database in one statement, so a burst of parallel guesses cannot
            // all read the same number and each write back "one more".
            await _db.PasswordResetCodes
                .Where(c => c.Id == candidate.Id && c.UsedAt == null)
                .ExecuteUpdateAsync(set => set
                    .SetProperty(c => c.Attempts, c => c.Attempts + 1)
                    .SetProperty(c => c.UsedAt, c => c.Attempts + 1 >= MaxAttempts ? now : null)
                    .SetProperty(c => c.UpdatedAt, now));
            return false;
        }

        // A correct code is spent the moment it is accepted. The conditional update also settles a
        // race — two requests with the same code cannot both get past this point.
        var spent = await _db.PasswordResetCodes
            .Where(c => c.Id == candidate.Id && c.UsedAt == null)
            .ExecuteUpdateAsync(set => set
                .SetProperty(c => c.UsedAt, now)
                .SetProperty(c => c.UpdatedAt, now));
        return spent > 0;
    }

    /// <summary>Never offered as a sign-in second factor; it only backs password resets.</summary>
    public Task<bool> CanGenerateTwoFactorTokenAsync(UserManager<ApplicationUser> manager, ApplicationUser user) =>
        Task.FromResult(false);

    /// <summary>A six-digit code, drawn from a cryptographic source so it cannot be guessed
    /// from the time it was issued.</summary>
    private static string GenerateCode() => RandomNumberGenerator.GetInt32(100000, 1000000).ToString();
}
