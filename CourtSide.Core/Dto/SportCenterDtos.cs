namespace CourtSide.Core.Dto;

public class SportCenterDto
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string Address { get; set; } = null!;
    public string? Description { get; set; }
    public int CityId { get; set; }
    public string? CityName { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
}

public class SportCenterUpsertDto
{
    public string Name { get; set; } = null!;
    public string Address { get; set; } = null!;
    public string? Description { get; set; }
    public int CityId { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
}
