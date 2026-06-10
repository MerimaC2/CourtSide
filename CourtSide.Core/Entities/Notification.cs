using CourtSide.Core.Entities.Base;
using CourtSide.Core.Entities.Identity;
using CourtSide.Core.Enumerations;

namespace CourtSide.Core.Entities;

/// <summary>A system notification delivered to a user (real-time via SignalR + persisted).</summary>
public class Notification : BaseEntity
{
    public int UserId { get; set; }
    public ApplicationUser User { get; set; } = null!;

    public string Title { get; set; } = null!;
    public string Text { get; set; } = null!;
    public bool IsRead { get; set; }
    public NotificationType Type { get; set; } = NotificationType.General;
}
