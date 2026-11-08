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

    public string? StripeRefundId { get; set; }
    public DateTime? RefundRequestedAt { get; set; }
    public string? RefundFailureReason { get; set; }

    // Which actions the rules allow right now, decided by PaymentPolicy on the server so the apps
    // never re-implement the table and can never offer a button the server would refuse.
    public bool CanCollectCash { get; set; }
    public bool CanStartOnlinePayment { get; set; }
    public bool CanRefund { get; set; }

    /// <summary>Whether an administrator may confirm a manual refund (cash, or a card payment with no
    /// processor reference) as paid back.</summary>
    public bool CanConfirmCashRefund { get; set; }

    /// <summary>Raw processor status, filled only by the verification call.</summary>
    public string? ProcessorStatus { get; set; }

    /// <summary>Whether the payment has reached a state that will not change on its own.</summary>
    public bool IsFinal { get; set; }
}
