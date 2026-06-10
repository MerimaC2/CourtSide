using CourtSide.Core.Dto;
using CourtSide.Core.Dto.Base;
using CourtSide.Core.Entities;
using CourtSide.Core.Enumerations;
using CourtSide.Core.Exceptions;
using CourtSide.Core.SearchObjects;
using CourtSide.Infrastructure;
using CourtSide.Shared.Services;
using Mapster;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace CourtSide.Services.Services;

public interface INotificationService
{
    Task CreateAsync(int userId, NotificationType type, string title, string text);
    Task<PagedResult<NotificationDto>> GetMyAsync(BaseSearchObject search);
    Task<int> GetUnreadCountAsync();
    Task MarkReadAsync(int id);
    Task MarkAllReadAsync();
}

public class NotificationService : INotificationService
{
    private readonly DatabaseContext _db;
    private readonly ICurrentUser _currentUser;

    public NotificationService(DatabaseContext db, ICurrentUser currentUser)
    {
        _db = db;
        _currentUser = currentUser;
    }

    public async Task CreateAsync(int userId, NotificationType type, string title, string text)
    {
        var notification = new Notification
        {
            UserId = userId,
            Type = type,
            Title = title,
            Text = text,
            IsRead = false,
            CreatedAt = DateTime.UtcNow
        };
        _db.Notifications.Add(notification);
        await _db.SaveChangesAsync();
        // Faza 2C: real-time push via SignalR is wired on top of this.
    }

    public async Task<PagedResult<NotificationDto>> GetMyAsync(BaseSearchObject search)
    {
        var userId = RequireUser();
        var query = _db.Notifications.Where(n => n.UserId == userId);

        var total = await query.CountAsync();
        var page = search.Page < 1 ? 1 : search.Page;
        var size = Math.Clamp(search.PageSize, 1, BaseSearchObject.MaxPageSize);

        var items = await query
            .OrderByDescending(n => n.CreatedAt)
            .Skip((page - 1) * size)
            .Take(size)
            .ProjectToType<NotificationDto>()
            .ToListAsync();

        return new PagedResult<NotificationDto> { Items = items, TotalCount = total, Page = page, PageSize = size };
    }

    public Task<int> GetUnreadCountAsync()
    {
        var userId = RequireUser();
        return _db.Notifications.CountAsync(n => n.UserId == userId && !n.IsRead);
    }

    public async Task MarkReadAsync(int id)
    {
        var userId = RequireUser();
        var notification = await _db.Notifications.FirstOrDefaultAsync(n => n.Id == id && n.UserId == userId)
            ?? throw new NotFoundException("Notifikacija", id);
        notification.IsRead = true;
        await _db.SaveChangesAsync();
    }

    public async Task MarkAllReadAsync()
    {
        var userId = RequireUser();
        await _db.Notifications
            .Where(n => n.UserId == userId && !n.IsRead)
            .ExecuteUpdateAsync(s => s.SetProperty(n => n.IsRead, true));
    }

    private int RequireUser() =>
        _currentUser.UserId ?? throw new BusinessException("Niste prijavljeni.");
}
