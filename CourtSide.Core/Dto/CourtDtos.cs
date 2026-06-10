namespace CourtSide.Core.Dto;

public class CourtDto
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string? Description { get; set; }

    public int SportId { get; set; }
    public string? SportName { get; set; }

    public int SportCenterId { get; set; }
    public string? SportCenterName { get; set; }

    public decimal PricePerHour { get; set; }
    public bool IsActive { get; set; }

    public int? PrimaryImageId { get; set; }
}

public class CourtUpsertDto
{
    public string Name { get; set; } = null!;
    public string? Description { get; set; }
    public int SportId { get; set; }
    public int SportCenterId { get; set; }
    public decimal PricePerHour { get; set; }
    public bool IsActive { get; set; } = true;
}
