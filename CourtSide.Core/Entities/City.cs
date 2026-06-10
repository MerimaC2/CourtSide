using CourtSide.Core.Entities.Base;

namespace CourtSide.Core.Entities;

/// <summary>Reference table: city used in addresses of sport centers.</summary>
public class City : BaseEntity
{
    public string Name { get; set; } = null!;
    public string? PostalCode { get; set; }

    public int CountryId { get; set; }
    public Country Country { get; set; } = null!;

    public ICollection<SportCenter> SportCenters { get; set; } = new List<SportCenter>();
}
