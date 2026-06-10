using CourtSide.Core.Entities;
using Microsoft.AspNetCore.Identity;

namespace CourtSide.Core.Entities.Identity;

/// <summary>
/// Application user (admin or client). Extends ASP.NET Identity with profile data and audit fields.
/// </summary>
public class ApplicationUser : IdentityUser<int>
{
    public string FirstName { get; set; } = null!;
    public string LastName { get; set; } = null!;

    public byte[]? ProfileImage { get; set; }
    public string? ProfileImageContentType { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public bool IsDeleted { get; set; }

    public ICollection<Reservation> Reservations { get; set; } = new List<Reservation>();
    public ICollection<Notification> Notifications { get; set; } = new List<Notification>();
    public ICollection<CourtReview> Reviews { get; set; } = new List<CourtReview>();
    public ICollection<CourtViewLog> CourtViews { get; set; } = new List<CourtViewLog>();
}
