using CourtSide.Core.Enumerations;

namespace CourtSide.Core.Dto;

/// <summary>Returned to the client to confirm a Stripe PaymentIntent (client completes payment with the secret).</summary>
public class PaymentIntentDto
{
    public string ClientSecret { get; set; } = null!;
    public string PublishableKey { get; set; } = null!;
    public long Amount { get; set; } // in the currency's smallest unit (e.g. fening)
    public string Currency { get; set; } = null!;
}

/// <summary>Current payment state for a reservation.</summary>
public class PaymentDto
{
    public int ReservationId { get; set; }
    public PaymentMethod Method { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = null!;
    public PaymentStatus Status { get; set; }
    public string? StripePaymentIntentId { get; set; }
    public DateTime? PaidAt { get; set; }
    public decimal? RefundedAmount { get; set; }
    public DateTime? RefundedAt { get; set; }
}
