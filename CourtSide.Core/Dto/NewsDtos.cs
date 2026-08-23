namespace CourtSide.Core.Dto;

public class NewsDto
{
    public int Id { get; set; }
    public string Title { get; set; } = null!;
    public string Text { get; set; } = null!;
    public DateTime PublishedAt { get; set; }
    public bool HasImage { get; set; }
}

public class NewsUpsertDto
{
    public string Title { get; set; } = null!;
    public string Text { get; set; } = null!;
    public DateTime? PublishedAt { get; set; }
}
