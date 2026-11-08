using CourtSide.Core.Entities.Base;
using CourtSide.Core.Enumerations;

namespace CourtSide.Core.Entities;

/// <summary>Payment record for a reservation (Stripe online or cash). One per reservation.</summary>
public class Payment : BaseEntity
{
    public int ReservationId { get; set; }
    public Reservation Reservation { get; set; } = null!;

    public PaymentMethod Method { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "BAM";
    public PaymentStatus Status { get; set; } = PaymentStatus.Pending;

    public string? StripePaymentIntentId { get; set; }
    public DateTime? PaidAt { get; set; }

    /// <summary>Administrator who recorded a cash payment; null for online payments.</summary>
    public int? PaidById { get; set; }

    public decimal? RefundedAmount { get; set; }
    public DateTime? RefundedAt { get; set; }

    // A refund reaches outside the database, so the intent is recorded before the call and the
    // outcome after it. Without that trail a crash mid-refund would leave money owed and no sign of it.

    /// <summary>Stripe refund id, so the final status can be confirmed against the processor.</summary>
    public string? StripeRefundId { get; set; }

    /// <summary>When the refund was initiated — set before the processor is contacted.</summary>
    public DateTime? RefundRequestedAt { get; set; }

    /// <summary>Why the refund failed, kept so an administrator can act on it.</summary>
    public string? RefundFailureReason { get; set; }

    /// <summary>Administrator who confirmed a manual refund (cash, or card payment without a processor
    /// reference) as handed back; null for online refunds.</summary>
    public int? RefundConfirmedById { get; set; }
}
