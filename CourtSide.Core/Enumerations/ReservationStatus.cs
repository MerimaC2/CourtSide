namespace CourtSide.Core.Enumerations;

/// <summary>
/// Reservation lifecycle: Pending -> Confirmed -> Completed, with Cancelled as a terminal state.
/// Transitions are enforced centrally by <c>ReservationStateMachine</c>.
/// </summary>
public enum ReservationStatus
{
    Pending = 1,
    Confirmed = 2,
    Cancelled = 3,
    Completed = 4
}
