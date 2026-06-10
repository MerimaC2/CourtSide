namespace CourtSide.Core.Dto;

public class CountryDto
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string? IsoCode { get; set; }
}

public class CountryUpsertDto
{
    public string Name { get; set; } = null!;
    public string? IsoCode { get; set; }
}
