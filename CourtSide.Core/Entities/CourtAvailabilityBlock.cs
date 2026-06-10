using CourtSide.Core.Entities.Base;
using CourtSide.Core.Entities.Identity;

namespace CourtSide.Core.Entities;

/// <summary>An admin-defined block of a court's time range (e.g. maintenance) making it unavailable.</summary>
public class CourtAvailabilityBlock : BaseEntity
{
    public int CourtId { get; set; }
    public Court Court { get; set; } = null!;

    public DateOnly Date { get; set; }
    public TimeOnly StartTime { get; set; }
    public TimeOnly EndTime { get; set; }
    public string? Reason { get; set; }

    public int CreatedById { get; set; }
    public ApplicationUser CreatedBy { get; set; } = null!;
}
