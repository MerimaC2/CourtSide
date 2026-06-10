using CourtSide.Core.Entities.Base;

namespace CourtSide.Core.Entities;

/// <summary>Reference table: country used for cities / user citizenship.</summary>
public class Country : BaseEntity
{
    public string Name { get; set; } = null!;
    public string? IsoCode { get; set; }

    public ICollection<City> Cities { get; set; } = new List<City>();
}
