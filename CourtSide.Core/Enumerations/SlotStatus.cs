namespace CourtSide.Core.Enumerations;

/// <summary>
/// Computed status of a time slot when presenting court availability (not persisted).
/// </summary>
public enum SlotStatus
{
    Available = 1,
    Reserved = 2,
    Blocked = 3
}
