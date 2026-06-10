using CourtSide.Core.Entities.Base;

namespace CourtSide.Core.Entities;

/// <summary>Image of a court (stored as bytes; served via a dedicated image endpoint).</summary>
public class CourtImage : BaseEntity
{
    public int CourtId { get; set; }
    public Court Court { get; set; } = null!;

    public byte[] ImageData { get; set; } = Array.Empty<byte>();
    public string ContentType { get; set; } = "image/jpeg";
    public bool IsPrimary { get; set; }
}
