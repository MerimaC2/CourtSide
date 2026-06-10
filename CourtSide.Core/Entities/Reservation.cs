using CourtSide.Core.Entities.Base;
using CourtSide.Core.Entities.Identity;
using CourtSide.Core.Enumerations;

namespace CourtSide.Core.Entities;

/// <summary>A booking of a court for a date and time range. Status transitions are enforced centrally.</summary>
public class Reservation : BaseEntity
{
    public string ReservationNumber { get; set; } = null!;

    public int ClientId { get; set; }
    public ApplicationUser Client { get; set; } = null!;

    public int CourtId { get; set; }
    public Court Court { get; set; } = null!;

    public DateOnly Date { get; set; }
    public TimeOnly StartTime { get; set; }
    public TimeOnly EndTime { get; set; }

    public decimal TotalPrice { get; set; }
    public ReservationStatus Status { get; set; } = ReservationStatus.Pending;

    // Contact details captured on the reservation form
    public string ContactName { get; set; } = null!;
    public string ContactPhone { get; set; } = null!;
    public string? Note { get; set; }

    // Audit trail for status changes
    public DateTime? ConfirmedAt { get; set; }
    public int? ConfirmedById { get; set; }
    public ApplicationUser? ConfirmedBy { get; set; }

    public DateTime? CancelledAt { get; set; }
    public int? CancelledById { get; set; }
    public ApplicationUser? CancelledBy { get; set; }
    public string? CancellationReason { get; set; }

    public Payment? Payment { get; set; }
}
