using CourtSide.Core.Enumerations;
using CourtSide.Core.Exceptions;

namespace CourtSide.Core.StateMachines;

/// <summary>
/// Centralized reservation status transitions. All status changes must go through here so the
/// rules live in one place (not scattered across controllers/services).
/// Pending -> Confirmed -> Completed, with Cancelled reachable from Pending/Confirmed.
/// </summary>
public static class ReservationStateMachine
{
    private static readonly Dictionary<ReservationStatus, HashSet<ReservationStatus>> Allowed = new()
    {
        [ReservationStatus.Pending] = new() { ReservationStatus.Confirmed, ReservationStatus.Cancelled },
        [ReservationStatus.Confirmed] = new() { ReservationStatus.Completed, ReservationStatus.Cancelled },
        [ReservationStatus.Completed] = new(),
        [ReservationStatus.Cancelled] = new()
    };

    public static bool CanTransition(ReservationStatus from, ReservationStatus to) =>
        Allowed.TryGetValue(from, out var targets) && targets.Contains(to);

    public static void EnsureCanTransition(ReservationStatus from, ReservationStatus to)
    {
        if (!CanTransition(from, to))
            throw new BusinessException(
                $"Nije moguća promjena statusa rezervacije sa '{from}' na '{to}'.");
    }
}
