using CourtSide.Core.Entities.Base;

namespace CourtSide.Core.Entities;

/// <summary>A sports facility that owns one or more courts. Holds map coordinates.</summary>
public class SportCenter : BaseEntity
{
    public string Name { get; set; } = null!;
    public string Address { get; set; } = null!;
    public string? Description { get; set; }

    public int CityId { get; set; }
    public City City { get; set; } = null!;

    public double? Latitude { get; set; }
    public double? Longitude { get; set; }

    public ICollection<Court> Courts { get; set; } = new List<Court>();
}
