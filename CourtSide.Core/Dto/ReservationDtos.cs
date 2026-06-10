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
