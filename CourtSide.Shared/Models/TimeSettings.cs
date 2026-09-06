namespace CourtSide.Shared.Models;

/// <summary>
/// Which local time the venue runs on. Court schedules, working hours and blocks are stored as
/// local wall-clock values, so every "has this slot passed?" question needs this zone to become
/// a point on the timeline. Audit timestamps stay UTC and do not use this.
/// </summary>
public class TimeSettings
{
    /// <summary>IANA id (Linux/containers) or the matching Windows id; both resolve on .NET 9.</summary>
    public string TimeZoneId { get; set; } = "Europe/Sarajevo";
}
