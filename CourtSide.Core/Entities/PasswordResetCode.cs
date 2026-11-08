using CourtSide.Core.Entities.Base;
using CourtSide.Core.Entities.Identity;

namespace CourtSide.Core.Entities;

/// <summary>
/// A one-time code emailed to a user who forgot their password. The code itself is never
/// stored — only its hash — so a leaked database still cannot be used to take over accounts.
/// A code is valid until <see cref="ExpiresAt"/> and only until it is used once.
/// </summary>
public class PasswordResetCode : BaseEntity
{
    public int UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public string CodeHash { get; set; } = null!;

    /// <summary>Failed attempts against this code; past the limit it is spent, so an emailed
    /// code cannot be guessed digit by digit while it is still valid.</summary>
    public int Attempts { get; set; }
    public DateTime ExpiresAt { get; set; }
    public DateTime? UsedAt { get; set; }
}
