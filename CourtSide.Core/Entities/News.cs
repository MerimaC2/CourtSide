using CourtSide.Core.Entities.Base;

namespace CourtSide.Core.Entities;

/// <summary>A news / announcement item (title, text, image, date).</summary>
public class News : BaseEntity
{
    public string Title { get; set; } = null!;
    public string Text { get; set; } = null!;

    public byte[]? ImageData { get; set; }
    public string? ImageContentType { get; set; }

    public DateTime PublishedAt { get; set; }
}
