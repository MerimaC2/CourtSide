using CourtSide.Core.Entities.Base;

namespace CourtSide.Core.Entities;

/// <summary>Working hours of a court for a given day of week (master-detail child of Court).</summary>
public class CourtWorkingHours : BaseEntity
{
    public int CourtId { get; set; }
    public Court Court { get; set; } = null!;

    public DayOfWeek DayOfWeek { get; set; }
    public TimeOnly OpenTime { get; set; }
    public TimeOnly CloseTime { get; set; }
}
