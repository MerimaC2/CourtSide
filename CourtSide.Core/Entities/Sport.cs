using CourtSide.Core.Entities.Base;

namespace CourtSide.Core.Entities;

/// <summary>Reference table: type of sport (futsal, tennis, padel, badminton, ...).</summary>
public class Sport : BaseEntity
{
    public string Name { get; set; } = null!;
    public string? Description { get; set; }

    public ICollection<Court> Courts { get; set; } = new List<Court>();
}
