using CourtSide.Core.Entities.Base;
using CourtSide.Core.Entities.Identity;

namespace CourtSide.Core.Entities;

/// <summary>A user's rating/review of a court (added after a completed reservation).</summary>
public class CourtReview : BaseEntity
{
    public int CourtId { get; set; }
    public Court Court { get; set; } = null!;

    public int UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public int? ReservationId { get; set; }
    public Reservation? Reservation { get; set; }

    public int Rating { get; set; }
    public string? Comment { get; set; }
}
