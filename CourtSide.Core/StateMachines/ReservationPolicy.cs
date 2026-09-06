namespace CourtSide.Core.StateMachines;

/// <summary>
/// Reservation rules that both the server enforces and the client displays. Keeping them here
/// means the API and the apps can never disagree about, say, how late a booking may be cancelled.
/// </summary>
public static class ReservationPolicy
{
    /// <summary>How close to the start a client may still cancel; admins are not bound by it.</summary>
    public static readonly TimeSpan CancellationWindow = TimeSpan.FromHours(24);

    /// <summary>Recorded on reservations the system closes because nobody confirmed them in time.</summary>
    public const string SystemExpiryReason =
        "Rezervacija nije potvrđena prije početka termina.";
}
