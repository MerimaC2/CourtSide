namespace CourtSide.Core.SearchObjects;

public class CourtSearchObject : BaseSearchObject
{
    public int? SportId { get; set; }
    public int? SportCenterId { get; set; }
    public int? CityId { get; set; }
    public bool? IsActive { get; set; }
    public decimal? MaxPricePerHour { get; set; }
}
