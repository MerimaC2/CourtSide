using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace CourtSide.Shared.Hubs;

/// <summary>
/// Real-time notification hub. Messages are sent to a specific user via Clients.User(userId),
/// where userId matches the JWT NameIdentifier claim.
/// </summary>
[Authorize]
public class NotificationHub : Hub
{
}
