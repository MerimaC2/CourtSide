using CourtSide.Core.Enumerations;

namespace CourtSide.Core.SearchObjects;

public class ReservationSearchObject : BaseSearchObject
{
    public int? CourtId { get; set; }
    public int? SportCenterId { get; set; }
    public ReservationStatus? Status { get; set; }
    public DateOnly? DateFrom { get; set; }
    public DateOnly? DateTo { get; set; }
}
