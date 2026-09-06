namespace CourtSide.Core.Enumerations;

public enum NotificationType
{
    ReservationCreated = 1,
    ReservationConfirmed = 2,
    ReservationCancelled = 3,
    ReservationCompleted = 4,
    PaymentCompleted = 5,
    PaymentRefunded = 6,
    General = 7,
    PaymentRefundPending = 8,
    PaymentRefundFailed = 9
}
