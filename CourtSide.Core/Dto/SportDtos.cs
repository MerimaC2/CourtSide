namespace CourtSide.Core.Dto;

public class SportDto
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string? Description { get; set; }
}

public class SportUpsertDto
{
    public string Name { get; set; } = null!;
    public string? Description { get; set; }
}
