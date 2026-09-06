namespace CourtSide.Core.Enumerations;

public enum PaymentStatus
{
    Pending = 1,
    Completed = 2,
    Refunded = 3,
    Failed = 4,

    /// <summary>Refund started but not settled: Stripe is still processing it, or cash is waiting
    /// for the administrator to confirm the money actually left the till.</summary>
    RefundPending = 5,

    /// <summary>Refund was attempted and failed; the reason is kept so it can be retried.</summary>
    RefundFailed = 6
}
