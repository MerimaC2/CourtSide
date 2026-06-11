namespace CourtSide.Core.Dto;

/// <summary>
/// A single explainable court recommendation returned to the mobile "Preporučeno" section.
/// </summary>
public class RecommendationDto
{
    public int CourtId { get; set; }
    public string CourtName { get; set; } = null!;
    public string? SportName { get; set; }
    public string? SportCenterName { get; set; }
    public decimal PricePerHour { get; set; }
    public int? PrimaryImageId { get; set; }

    /// <summary>Predicted preference score (higher = stronger). 0 for fallback recommendations.</summary>
    public double Score { get; set; }

    /// <summary>Human-readable reason, e.g. collaborative-filtering match or popularity fallback.</summary>
    public string Reason { get; set; } = null!;
}
