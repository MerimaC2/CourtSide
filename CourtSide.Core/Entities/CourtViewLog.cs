using CourtSide.Core.Entities.Base;
using CourtSide.Core.Entities.Identity;

namespace CourtSide.Core.Entities;

/// <summary>
/// Records that a user viewed a court. Real implicit signal used by the recommender
/// (browsing history) in addition to reservations.
/// </summary>
public class CourtViewLog : BaseEntity
{
    public int UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public int CourtId { get; set; }
    public Court Court { get; set; } = null!;

    public DateTime ViewedAt { get; set; }
}
