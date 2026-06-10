namespace CourtSide.Core.Dto;

public class CityDto
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string? PostalCode { get; set; }
    public int CountryId { get; set; }
    public string? CountryName { get; set; }
}

public class CityUpsertDto
{
    public string Name { get; set; } = null!;
    public string? PostalCode { get; set; }
    public int CountryId { get; set; }
}
