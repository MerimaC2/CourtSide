using CourtSide.Core.Enumerations;

namespace CourtSide.Core.Dto;

/// <summary>A single time slot with its computed status (available/reserved/blocked).</summary>
public class AvailabilitySlotDto
{
    public TimeOnly StartTime { get; set; }
    public TimeOnly EndTime { get; set; }
    public SlotStatus Status { get; set; }

    /// <summary>
    /// Whether the slot has already started, decided against the venue's local time. The apps
    /// must not work this out from device time — they would disagree with the server, which
    /// rejects bookings for slots that have begun.
    /// </summary>
    public bool IsPast { get; set; }
}

public class AvailabilityBlockDto
{
    public int Id { get; set; }
    public int CourtId { get; set; }
    public string? CourtName { get; set; }
    public DateOnly Date { get; set; }
    public TimeOnly StartTime { get; set; }
    public TimeOnly EndTime { get; set; }
    public string? Reason { get; set; }
}

public class AvailabilityBlockUpsertDto
{
    public int CourtId { get; set; }
    public DateOnly Date { get; set; }
    public TimeOnly StartTime { get; set; }
    public TimeOnly EndTime { get; set; }
    public string? Reason { get; set; }
}
