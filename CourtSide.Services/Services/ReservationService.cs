using CourtSide.Core.Dto;
using CourtSide.Core.Dto.Base;
using CourtSide.Core.Entities;
using CourtSide.Core.Enumerations;
using CourtSide.Core.Exceptions;
using CourtSide.Core.Helpers;
using CourtSide.Core.SearchObjects;
using CourtSide.Core.StateMachines;
using CourtSide.Infrastructure;
using CourtSide.Services.Payments;
using CourtSide.Shared.Messages;
using CourtSide.Shared.Messaging;
using CourtSide.Shared.Services;
using Mapster;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CourtSide.Services.Services;

public interface IReservationService
{
    Task<PagedResult<ReservationDto>> GetPagedAsync(ReservationSearchObject search);
    Task<PagedResult<ReservationDto>> GetMyAsync(ReservationSearchObject search);
    Task<ReservationDto> GetByIdAsync(int id);
    Task<ReservationDto> CreateAsync(ReservationCreateDto dto);
    Task<ReservationDto> ConfirmAsync(int id);
    Task<ReservationDto> CancelAsync(int id, ReservationCancelDto dto);
    Task<int> CompletePastDueAsync(CancellationToken cancellationToken = default);
}

public class ReservationService : IReservationService
{
    private readonly DatabaseContext _db;
    private readonly ICurrentUser _currentUser;
    private readonly INotificationService _notifications;
    private readonly IMessagePublisher _publisher;
    private readonly IPaymentService _payments;
    private readonly IAppClock _clock;
    private readonly ILogger<ReservationService> _logger;

    public ReservationService(DatabaseContext db, ICurrentUser currentUser,
        INotificationService notifications, IMessagePublisher publisher,
        IPaymentService payments, IAppClock clock, ILogger<ReservationService> logger)
    {
        _db = db;
        _currentUser = currentUser;
        _notifications = notifications;
        _publisher = publisher;
        _payments = payments;
        _clock = clock;
        _logger = logger;
    }

    public async Task<PagedResult<ReservationDto>> GetPagedAsync(ReservationSearchObject search)
        => await QueryAsync(search, _db.Reservations.AsQueryable());

    public async Task<PagedResult<ReservationDto>> GetMyAsync(ReservationSearchObject search)
    {
        var userId = RequireUser();
        return await QueryAsync(search, _db.Reservations.Where(r => r.ClientId == userId));
    }

    public async Task<ReservationDto> GetByIdAsync(int id)
    {
        var dto = await _db.Reservations.Where(r => r.Id == id)
            .ProjectToType<ReservationDto>()
            .FirstOrDefaultAsync()
            ?? throw new NotFoundException("Rezervacija", id);

        if (!_currentUser.IsAdmin && dto.ClientId != _currentUser.UserId)
            throw new BusinessException("Nemate pristup ovoj rezervaciji.");

        ApplyComputedFlags(dto);

        return dto;
    }

    public async Task<ReservationDto> CreateAsync(ReservationCreateDto dto)
    {
        var userId = RequireUser();

        var court = await _db.Courts.Include(c => c.WorkingHours)
            .FirstOrDefaultAsync(c => c.Id == dto.CourtId)
            ?? throw new NotFoundException("Teren", dto.CourtId);

        if (!court.IsActive)
            throw new BusinessException("Teren trenutno nije dostupan za rezervaciju.");

        if (dto.EndTime <= dto.StartTime)
            throw new BusinessException("Vrijeme završetka mora biti nakon vremena početka.");

        if (_clock.HasPassed(dto.Date, dto.StartTime))
            throw new BusinessException("Termin rezervacije mora biti u budućnosti.");

        var workingHours = court.WorkingHours.FirstOrDefault(w => w.DayOfWeek == dto.Date.DayOfWeek);
        if (workingHours is null || dto.StartTime < workingHours.OpenTime || dto.EndTime > workingHours.CloseTime)
            throw new BusinessException("Odabrani termin je izvan radnog vremena terena.");

        // Overlap check on the server (not only on the client).
        var overlapsReservation = await _db.Reservations.AnyAsync(r =>
            r.CourtId == dto.CourtId && r.Date == dto.Date &&
            r.Status != ReservationStatus.Cancelled &&
            r.StartTime < dto.EndTime && dto.StartTime < r.EndTime);
        if (overlapsReservation)
            throw new BusinessException("Odabrani termin je već rezervisan.");

        var overlapsBlock = await _db.CourtAvailabilityBlocks.AnyAsync(b =>
            b.CourtId == dto.CourtId && b.Date == dto.Date &&
            b.StartTime < dto.EndTime && dto.StartTime < b.EndTime);
        if (overlapsBlock)
            throw new BusinessException("Odabrani termin je blokiran i nije dostupan.");

        var hours = (decimal)(dto.EndTime.ToTimeSpan() - dto.StartTime.ToTimeSpan()).TotalHours;
        var totalPrice = Math.Round(court.PricePerHour * hours, 2);
        var now = DateTime.UtcNow;

        var reservation = new Reservation
        {
            ReservationNumber = ReservationNumber.Generate(),
            ClientId = userId,
            CourtId = dto.CourtId,
            Date = dto.Date,
            StartTime = dto.StartTime,
            EndTime = dto.EndTime,
            TotalPrice = totalPrice,
            Status = ReservationStatus.Pending,
            ContactName = dto.ContactName,
            ContactPhone = dto.ContactPhone,
            Note = dto.Note,
            CreatedAt = now,
            Payment = new Payment
            {
                Method = dto.PaymentMethod,
                Amount = totalPrice,
                Currency = "BAM",
                Status = PaymentStatus.Pending,
                CreatedAt = now
            }
        };

        // The reservation and its notification are separate saves, so they share one transaction.
        await using (var transaction = await _db.Database.BeginTransactionAsync())
        {
            _db.Reservations.Add(reservation);
            await _db.SaveChangesAsync();

            await _notifications.CreateAsync(userId, NotificationType.ReservationCreated,
                "Rezervacija kreirana",
                $"Vaša rezervacija {ReservationNumber.Short(reservation.ReservationNumber)} je kreirana i čeka potvrdu.");
            await transaction.CommitAsync();
        }
        await SendEmailAsync(userId, "Potvrda kreiranja rezervacije",
            $"Vaša rezervacija {ReservationNumber.Short(reservation.ReservationNumber)} je kreirana i čeka potvrdu.");

        return await GetByIdAsync(reservation.Id);
    }

    public async Task<ReservationDto> ConfirmAsync(int id)
    {
        var reservation = await _db.Reservations.FirstOrDefaultAsync(r => r.Id == id)
            ?? throw new NotFoundException("Rezervacija", id);

        ReservationStateMachine.EnsureCanTransition(reservation.Status, ReservationStatus.Confirmed);

        reservation.Status = ReservationStatus.Confirmed;
        reservation.ConfirmedAt = DateTime.UtcNow;
        reservation.ConfirmedById = _currentUser.UserId;
        reservation.UpdatedAt = DateTime.UtcNow;

        // The status change and its notification are separate saves, so they share one transaction.
        await using (var transaction = await _db.Database.BeginTransactionAsync())
        {
            await _db.SaveChangesAsync();

            await _notifications.CreateAsync(reservation.ClientId, NotificationType.ReservationConfirmed,
                "Rezervacija potvrđena",
                $"Vaša rezervacija {ReservationNumber.Short(reservation.ReservationNumber)} je potvrđena.");
            await transaction.CommitAsync();
        }
        await SendEmailAsync(reservation.ClientId, "Rezervacija potvrđena",
            $"Vaša rezervacija {ReservationNumber.Short(reservation.ReservationNumber)} je potvrđena.");

        return await GetByIdAsync(reservation.Id);
    }

    public async Task<ReservationDto> CancelAsync(int id, ReservationCancelDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Reason))
            throw new BusinessException("Razlog otkazivanja je obavezan.");

        var reservation = await _db.Reservations.FirstOrDefaultAsync(r => r.Id == id)
            ?? throw new NotFoundException("Rezervacija", id);

        var isOwner = reservation.ClientId == _currentUser.UserId;
        if (!_currentUser.IsAdmin && !isOwner)
            throw new BusinessException("Nemate pravo otkazati ovu rezervaciju.");

        ReservationStateMachine.EnsureCanTransition(reservation.Status, ReservationStatus.Cancelled);

        // Clients can cancel up to 24h before the start; admins may cancel anytime.
        if (!_currentUser.IsAdmin &&
            _clock.TimeUntil(reservation.Date, reservation.StartTime) < ReservationPolicy.CancellationWindow)
            throw new BusinessException("Rezervaciju je moguće otkazati najkasnije 24 sata prije termina.");

        reservation.Status = ReservationStatus.Cancelled;
        reservation.CancelledAt = DateTime.UtcNow;
        reservation.CancelledById = _currentUser.UserId;
        reservation.CancellationReason = dto.Reason;
        reservation.UpdatedAt = DateTime.UtcNow;

        // The status change and its notification are separate saves, so they share one transaction.
        // The refund stays outside it — it talks to Stripe over the network and must not hold the
        // transaction open, and its failure must not undo the cancellation.
        await using (var transaction = await _db.Database.BeginTransactionAsync())
        {
            await _db.SaveChangesAsync();

            await _notifications.CreateAsync(reservation.ClientId, NotificationType.ReservationCancelled,
                "Rezervacija otkazana",
                $"Rezervacija {ReservationNumber.Short(reservation.ReservationNumber)} je otkazana. Razlog: {dto.Reason}");
            await transaction.CommitAsync();
        }

        // Refund any completed payment (Stripe online or cash). A refund failure must not block cancellation.
        try
        {
            await _payments.RefundAsync(reservation.Id);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Otkazivanje {Number}: automatski povrat nije uspio — potreban ručni povrat.",
                reservation.ReservationNumber);
        }

        await SendEmailAsync(reservation.ClientId, "Rezervacija otkazana",
            $"Rezervacija {ReservationNumber.Short(reservation.ReservationNumber)} je otkazana. Razlog: {dto.Reason}");

        return await GetByIdAsync(reservation.Id);
    }

    /// <summary>
    /// Moves confirmed reservations whose slot has already elapsed to <see cref="ReservationStatus.Completed"/>
    /// and notifies the client. Driven by <c>ReservationCompletionService</c> rather than a user action,
    /// since completion happens with the passage of time. Returns how many were completed.
    /// </summary>
    public async Task<int> CompletePastDueAsync(CancellationToken cancellationToken = default)
    {
        // The slot is local wall-clock; the audit stamp stays UTC.
        var now = _clock.UtcNow;
        var today = _clock.Today;
        var timeOfDay = _clock.LocalTimeOfDay;

        // Date and time are compared separately so the filter runs in SQL instead of
        // pulling every confirmed reservation into memory.
        var pastDue = await _db.Reservations
            .Where(r => r.Status == ReservationStatus.Confirmed &&
                        (r.Date < today || (r.Date == today && r.EndTime <= timeOfDay)))
            .ToListAsync(cancellationToken);

        if (pastDue.Count == 0) return 0;

        // The status updates and their notifications are saved separately, so they share
        // one transaction and either all land or none do.
        await using var transaction = await _db.Database.BeginTransactionAsync(cancellationToken);

        foreach (var reservation in pastDue)
        {
            ReservationStateMachine.EnsureCanTransition(reservation.Status, ReservationStatus.Completed);
            reservation.Status = ReservationStatus.Completed;
            reservation.CompletedAt = now;
            reservation.UpdatedAt = now;
        }
        await _db.SaveChangesAsync(cancellationToken);

        foreach (var reservation in pastDue)
        {
            await _notifications.CreateAsync(reservation.ClientId, NotificationType.ReservationCompleted,
                "Rezervacija završena",
                $"Vaša rezervacija {ReservationNumber.Short(reservation.ReservationNumber)} je završena. Možete ocijeniti teren.");
        }

        await transaction.CommitAsync(cancellationToken);
        return pastDue.Count;
    }

    private async Task<PagedResult<ReservationDto>> QueryAsync(ReservationSearchObject search, IQueryable<Reservation> query)
    {
        if (search.CourtId.HasValue)
            query = query.Where(r => r.CourtId == search.CourtId);
        if (search.SportCenterId.HasValue)
            query = query.Where(r => r.Court.SportCenterId == search.SportCenterId);
        if (search.Status.HasValue)
            query = query.Where(r => r.Status == search.Status);
        if (search.DateFrom.HasValue)
            query = query.Where(r => r.Date >= search.DateFrom);
        if (search.DateTo.HasValue)
            query = query.Where(r => r.Date <= search.DateTo);
        if (!string.IsNullOrWhiteSpace(search.SearchTerm))
            query = query.Where(r => r.ReservationNumber.Contains(search.SearchTerm));

        var total = await query.CountAsync();
        var page = search.Page < 1 ? 1 : search.Page;
        var size = Math.Clamp(search.PageSize, 1, BaseSearchObject.MaxPageSize);

        var items = await query
            .OrderByDescending(r => r.Date).ThenByDescending(r => r.StartTime)
            .Skip((page - 1) * size)
            .Take(size)
            .ProjectToType<ReservationDto>()
            .ToListAsync();

        foreach (var item in items) ApplyComputedFlags(item);

        return new PagedResult<ReservationDto> { Items = items, TotalCount = total, Page = page, PageSize = size };
    }

    /// <summary>
    /// Fills the time-dependent fields the projection cannot produce (they need the venue's time
    /// zone, which does not translate to SQL). The cancellation rule here is the same one
    /// <see cref="CancelAsync"/> enforces, so the apps and the server can never disagree.
    /// </summary>
    private void ApplyComputedFlags(ReservationDto dto)
    {
        dto.StartsAt = _clock.ToInstant(dto.Date, dto.StartTime);
        dto.EndsAt = _clock.ToInstant(dto.Date, dto.EndTime);

        var cancellable = dto.Status is ReservationStatus.Pending or ReservationStatus.Confirmed;
        var deadline = dto.StartsAt - ReservationPolicy.CancellationWindow;

        dto.CancelDeadlineAt = cancellable ? deadline : null;
        dto.CanCancel = cancellable &&
            (_currentUser.IsAdmin || _clock.TimeUntil(dto.Date, dto.StartTime) >= ReservationPolicy.CancellationWindow);
    }

    private async Task SendEmailAsync(int userId, string subject, string body)
    {
        var email = await _db.Users.Where(u => u.Id == userId).Select(u => u.Email).FirstOrDefaultAsync();
        if (!string.IsNullOrWhiteSpace(email))
            await _publisher.PublishAsync(new EmailMessage { To = email!, Subject = subject, Body = body });
    }

    private int RequireUser() =>
        _currentUser.UserId ?? throw new BusinessException("Niste prijavljeni.");
}
