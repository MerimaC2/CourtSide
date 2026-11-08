namespace CourtSide.Core.Dto;

/// <summary>Opening hours of a court on one day of the week.</summary>
public class CourtWorkingHoursDto
{
    public DayOfWeek DayOfWeek { get; set; }
    public TimeOnly OpenTime { get; set; }
    public TimeOnly CloseTime { get; set; }
}

public class CourtDto
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string? Description { get; set; }

    public int SportId { get; set; }
    public string? SportName { get; set; }

    public int SportCenterId { get; set; }
    public string? SportCenterName { get; set; }
    public string? SportCenterAddress { get; set; }
    public string? CityName { get; set; }

    public decimal PricePerHour { get; set; }
    public bool IsActive { get; set; }

    public int? PrimaryImageId { get; set; }
    public double? AverageRating { get; set; }
    public int ReviewCount { get; set; }

    /// Days the court is open. Availability is derived from these, so a court with none
    /// has no bookable slots at all.
    public List<CourtWorkingHoursDto> WorkingHours { get; set; } = [];
}

public class CourtUpsertDto
{
    public string Name { get; set; } = null!;
    public string? Description { get; set; }
    public int SportId { get; set; }
    public int SportCenterId { get; set; }
    public decimal PricePerHour { get; set; }
    public bool IsActive { get; set; } = true;

    /// <summary>Required: an omitted list is rejected, while an empty one means the court is closed
    /// and has no bookable slots.</summary>
    public List<CourtWorkingHoursDto>? WorkingHours { get; set; }
}
