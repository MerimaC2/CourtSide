namespace CourtSide.Core.Dto;

public class CourtReviewDto
{
    public int Id { get; set; }
    public int CourtId { get; set; }
    public string? CourtName { get; set; }
    public int UserId { get; set; }
    public string? UserName { get; set; }
    public int? ReservationId { get; set; }
    public int Rating { get; set; }
    public string? Comment { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class CourtReviewUpsertDto
{
    public int ReservationId { get; set; }
    public int Rating { get; set; }
    public string? Comment { get; set; }
}
