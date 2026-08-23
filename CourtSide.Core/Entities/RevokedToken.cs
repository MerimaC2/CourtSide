using CourtSide.Core.Entities.Base;

namespace CourtSide.Core.Entities;

/// <summary>
/// A JWT that was invalidated by logging out. Access tokens are self-contained, so signing
/// out has to be recorded server-side for the token to stop being accepted before it expires.
/// Entries are keyed by the token's <c>jti</c> claim and are purged once past <see cref="ExpiresAt"/>.
/// </summary>
public class RevokedToken : BaseEntity
{
    public string TokenId { get; set; } = null!;
    public int UserId { get; set; }
    public DateTime ExpiresAt { get; set; }
}
