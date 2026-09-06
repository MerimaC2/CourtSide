using CourtSide.Core.Enumerations;
using CourtSide.Core.Exceptions;

namespace CourtSide.Core.StateMachines;

/// <summary>
/// Which payment actions are allowed for which combination of reservation status and payment
/// status. Written out as an explicit table rather than scattered conditions, so the rules can be
/// read in one place and the same answer is used by the services and by the apps' buttons.
/// Anything not listed is denied — a combination can never be left undefined by omission.
/// </summary>
public static class PaymentPolicy
{
    /// <summary>
    /// How long after a slot finishes cash may still be recorded. A reservation turns Completed on
    /// its own once the slot passes, while the money is handed over at the court — often minutes
    /// later — so a hard cut-off at Completed would leave real income impossible to record. The
    /// window keeps the terminal state from being editable indefinitely.
    /// </summary>
    public static readonly TimeSpan CashGraceAfterCompletion = TimeSpan.FromDays(7);

    /// <summary>Payment states in which money has been collected and not yet given back.</summary>
    private static readonly HashSet<PaymentStatus> Collected = [PaymentStatus.Completed];

    /// <summary>Payment states in which nothing has been collected, so a refund has no subject.</summary>
    private static readonly HashSet<PaymentStatus> NotCollected =
        [PaymentStatus.Pending, PaymentStatus.Failed];

    /// <summary>Reservation states that may still be paid for.</summary>
    private static readonly HashSet<ReservationStatus> Payable =
        [ReservationStatus.Pending, ReservationStatus.Confirmed];

    /// <summary>
    /// Extra context the rules need beyond the two statuses: when the slot finished (for the cash
    /// window) and what "now" is.
    /// </summary>
    public readonly record struct Context(DateTime? CompletedAt, DateTime UtcNow);

    public static PolicyOutcome Evaluate(ReservationStatus reservation, PaymentStatus payment,
        PaymentMethod method, PaymentAction action, Context context = default) => action switch
    {
        PaymentAction.CollectCash => CollectCash(reservation, payment, context),
        PaymentAction.StartOnlinePayment => StartOnlinePayment(reservation, payment),
        PaymentAction.Refund => Refund(reservation, payment),
        PaymentAction.ConfirmCashRefund => ConfirmCashRefund(reservation, payment, method),
        _ => PolicyOutcome.Denied
    };

    public static bool IsAllowed(ReservationStatus reservation, PaymentStatus payment,
        PaymentMethod method, PaymentAction action, Context context = default)
        => Evaluate(reservation, payment, method, action, context) == PolicyOutcome.Allowed;

    /// <summary>Throws with the reason when the action is not allowed; returns the outcome otherwise.</summary>
    public static PolicyOutcome EnsureAllowed(ReservationStatus reservation, PaymentStatus payment,
        PaymentMethod method, PaymentAction action, Context context = default)
    {
        var outcome = Evaluate(reservation, payment, method, action, context);
        if (outcome == PolicyOutcome.Denied)
            throw new BusinessException(Explain(reservation, payment, action));
        return outcome;
    }

    /// <summary>
    /// The payment method may only change while nothing has been collected — otherwise a booking
    /// paid in cash could later be recorded as a card payment.
    /// </summary>
    public static bool CanChangeMethod(PaymentStatus payment) => NotCollected.Contains(payment);

    private static PolicyOutcome CollectCash(ReservationStatus reservation, PaymentStatus payment, Context context)
    {
        if (!NotCollected.Contains(payment)) return PolicyOutcome.Denied;
        if (Payable.Contains(reservation)) return PolicyOutcome.Allowed;

        // The service was delivered, so the money is genuinely owed — but only briefly.
        if (reservation == ReservationStatus.Completed)
        {
            var finishedAt = context.CompletedAt ?? DateTime.MinValue;
            return context.UtcNow - finishedAt <= CashGraceAfterCompletion
                ? PolicyOutcome.Allowed
                : PolicyOutcome.Denied;
        }

        return PolicyOutcome.Denied; // cancelled reservations are never collected on
    }

    private static PolicyOutcome StartOnlinePayment(ReservationStatus reservation, PaymentStatus payment)
        => Payable.Contains(reservation) && NotCollected.Contains(payment)
            ? PolicyOutcome.Allowed
            : PolicyOutcome.Denied;

    private static PolicyOutcome Refund(ReservationStatus reservation, PaymentStatus payment)
    {
        // Nothing was ever collected, or the refund is already under way or done: no work to do,
        // and not a mistake either — cancelling an unpaid booking must not fail.
        if (NotCollected.Contains(payment) ||
            payment is PaymentStatus.Refunded or PaymentStatus.RefundPending)
            return PolicyOutcome.NoOp;

        // Money is only given back once the booking itself is cancelled; otherwise the court would
        // stay reserved while the client has been repaid.
        if (reservation != ReservationStatus.Cancelled) return PolicyOutcome.Denied;

        return Collected.Contains(payment) || payment == PaymentStatus.RefundFailed
            ? PolicyOutcome.Allowed // a failed refund may be retried
            : PolicyOutcome.Denied;
    }

    private static PolicyOutcome ConfirmCashRefund(ReservationStatus reservation, PaymentStatus payment,
        PaymentMethod method)
        => reservation == ReservationStatus.Cancelled &&
           payment == PaymentStatus.RefundPending &&
           method == PaymentMethod.Cash
            ? PolicyOutcome.Allowed // an online refund is confirmed by the processor, not by a person
            : PolicyOutcome.Denied;

    private static string Explain(ReservationStatus reservation, PaymentStatus payment, PaymentAction action)
    {
        if (payment == PaymentStatus.Completed && action != PaymentAction.Refund)
            return "Rezervacija je već plaćena.";
        if (payment is PaymentStatus.Refunded or PaymentStatus.RefundPending && action != PaymentAction.Refund)
            return "Plaćanje je već refundirano.";
        if (reservation == ReservationStatus.Cancelled)
            return "Rezervacija je otkazana pa se na njoj može izvršiti samo povrat sredstava.";
        if (reservation == ReservationStatus.Completed && action == PaymentAction.CollectCash)
            return "Rok za naknadnu evidenciju gotovinske uplate (7 dana) je istekao.";
        if (reservation == ReservationStatus.Completed && action == PaymentAction.StartOnlinePayment)
            return "Termin je završen — online plaćanje više nije moguće, uplata se evidentira na terenu.";
        if (action == PaymentAction.Refund)
            return "Povrat je moguć samo za otkazanu rezervaciju. Prvo otkažite rezervaciju.";
        if (action == PaymentAction.ConfirmCashRefund)
            return "Nema gotovinskog povrata koji čeka potvrdu.";
        return "Ova radnja nije dozvoljena za trenutno stanje rezervacije i plaćanja.";
    }
}
