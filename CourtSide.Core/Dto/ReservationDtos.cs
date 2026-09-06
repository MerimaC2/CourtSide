using CourtSide.Core.Enumerations;

namespace CourtSide.Core.Dto;

public class ReservationDto
{
    public int Id { get; set; }
    public string ReservationNumber { get; set; } = null!;

    public int ClientId { get; set; }
    public string? ClientName { get; set; }

    public int CourtId { get; set; }
    public string? CourtName { get; set; }
    public string? SportCenterName { get; set; }

    public DateOnly Date { get; set; }
    public TimeOnly StartTime { get; set; }
    public TimeOnly EndTime { get; set; }

    public decimal TotalPrice { get; set; }
    public ReservationStatus Status { get; set; }

    public string ContactName { get; set; } = null!;
    public string ContactPhone { get; set; } = null!;
    public string? Note { get; set; }
    public string? CancellationReason { get; set; }
    public DateTime CreatedAt { get; set; }

    public PaymentMethod? PaymentMethod { get; set; }
    public PaymentStatus? PaymentStatus { get; set; }
    public bool IsPaid { get; set; }
    public bool HasReview { get; set; }

    // Decided on the server so the apps never re-derive them from device time: the slot is stored
    // as local wall-clock, and a client in another zone would reach a different answer than the
    // rules the server actually enforces.

    /// <summary>Start of the slot as a point on the timeline, with the venue's offset applied.</summary>
    public DateTimeOffset StartsAt { get; set; }

    /// <summary>End of the slot as a point on the timeline.</summary>
    public DateTimeOffset EndsAt { get; set; }

    /// <summary>Whether the signed-in user may still cancel — same rule <c>CancelAsync</c> enforces.</summary>
    public bool CanCancel { get; set; }

    /// <summary>Last moment a client can cancel; null once cancelling is no longer possible.</summary>
    public DateTimeOffset? CancelDeadlineAt { get; set; }
}

public class ReservationCreateDto
{
    public int CourtId { get; set; }
    public DateOnly Date { get; set; }
    public TimeOnly StartTime { get; set; }
    public TimeOnly EndTime { get; set; }

    public string ContactName { get; set; } = null!;
    public string ContactPhone { get; set; } = null!;
    public string? Note { get; set; }

    public PaymentMethod PaymentMethod { get; set; } = PaymentMethod.Cash;
}

public class ReservationCancelDto
{
    public string Reason { get; set; } = null!;
}
