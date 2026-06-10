using CourtSide.Core.Entities.Base;

namespace CourtSide.Core.Entities;

/// <summary>A bookable sports court belonging to a sport center.</summary>
public class Court : BaseEntity
{
    public string Name { get; set; } = null!;
    public string? Description { get; set; }

    public int SportId { get; set; }
    public Sport Sport { get; set; } = null!;

    public int SportCenterId { get; set; }
    public SportCenter SportCenter { get; set; } = null!;

    public decimal PricePerHour { get; set; }
    public bool IsActive { get; set; } = true;

    public ICollection<CourtImage> Images { get; set; } = new List<CourtImage>();
    public ICollection<CourtWorkingHours> WorkingHours { get; set; } = new List<CourtWorkingHours>();
    public ICollection<CourtAvailabilityBlock> Blocks { get; set; } = new List<CourtAvailabilityBlock>();
    public ICollection<Reservation> Reservations { get; set; } = new List<Reservation>();
    public ICollection<CourtReview> Reviews { get; set; } = new List<CourtReview>();
}
