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

    public decimal? RefundedAmount { get; set; }
    public DateTime? RefundedAt { get; set; }
}
