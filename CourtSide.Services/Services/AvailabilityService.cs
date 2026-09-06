using CourtSide.Core.Dto;
using CourtSide.Core.Entities;
using CourtSide.Core.Enumerations;
using CourtSide.Core.Exceptions;
using CourtSide.Core.Helpers;
using CourtSide.Infrastructure;
using CourtSide.Shared.Services;
using Mapster;
using Microsoft.EntityFrameworkCore;

namespace CourtSide.Services.Services;

public interface IAvailabilityService
{
    Task<List<AvailabilitySlotDto>> GetSlotsAsync(int courtId, DateOnly date);
    Task<List<AvailabilityBlockDto>> GetBlocksAsync(int courtId, DateOnly date);
    Task<AvailabilityBlockDto> AddBlockAsync(AvailabilityBlockUpsertDto dto);
    Task RemoveBlockAsync(int id);
}

public class AvailabilityService : IAvailabilityService
{
    private readonly DatabaseContext _db;
    private readonly ICurrentUser _currentUser;
    private readonly IAppClock _clock;

    public AvailabilityService(DatabaseContext db, ICurrentUser currentUser, IAppClock clock)
    {
        _db = db;
        _currentUser = currentUser;
        _clock = clock;
    }

    public async Task<List<AvailabilitySlotDto>> GetSlotsAsync(int courtId, DateOnly date)
    {
        var court = await _db.Courts.Include(c => c.WorkingHours)
            .FirstOrDefaultAsync(c => c.Id == courtId)
            ?? throw new NotFoundException("Teren", courtId);

        var workingHours = court.WorkingHours.FirstOrDefault(w => w.DayOfWeek == date.DayOfWeek);
        var slots = new List<AvailabilitySlotDto>();
        if (workingHours is null) return slots; // closed on this day

        var reservations = await _db.Reservations
            .Where(r => r.CourtId == courtId && r.Date == date && r.Status != ReservationStatus.Cancelled)
            .Select(r => new { r.StartTime, r.EndTime })
            .ToListAsync();

        var blocks = await _db.CourtAvailabilityBlocks
            .Where(b => b.CourtId == courtId && b.Date == date)
            .Select(b => new { b.StartTime, b.EndTime })
            .ToListAsync();

        foreach (var (slotStart, slotEnd) in SlotGrid.Build(workingHours.OpenTime, workingHours.CloseTime))
        {
            // Reservations are checked first: a booked slot must stay visible as booked even if a
            // block was somehow recorded over it, otherwise the schedule hides a real reservation.
            var status = SlotStatus.Available;
            if (reservations.Any(r => SlotGrid.Overlaps(r.StartTime, r.EndTime, slotStart, slotEnd)))
                status = SlotStatus.Reserved;
            else if (blocks.Any(b => SlotGrid.Overlaps(b.StartTime, b.EndTime, slotStart, slotEnd)))
                status = SlotStatus.Blocked;

            slots.Add(new AvailabilitySlotDto
            {
                StartTime = slotStart,
                EndTime = slotEnd,
                Status = status,
                IsPast = _clock.HasPassed(date, slotStart)
            });
        }

        return slots;
    }

    public async Task<List<AvailabilityBlockDto>> GetBlocksAsync(int courtId, DateOnly date)
    {
        return await _db.CourtAvailabilityBlocks
            .Where(b => b.CourtId == courtId && b.Date == date)
            .ProjectToType<AvailabilityBlockDto>()
            .ToListAsync();
    }

    public async Task<AvailabilityBlockDto> AddBlockAsync(AvailabilityBlockUpsertDto dto)
    {
        var userId = _currentUser.UserId ?? throw new BusinessException("Niste prijavljeni.");

        var court = await _db.Courts.Include(c => c.WorkingHours)
            .FirstOrDefaultAsync(c => c.Id == dto.CourtId)
            ?? throw new NotFoundException("Teren", dto.CourtId);

        if (dto.EndTime <= dto.StartTime)
            throw new BusinessException("Vrijeme završetka mora biti nakon vremena početka.");

        if (_clock.HasPassed(dto.Date, dto.StartTime))
            throw new BusinessException("Termin je već počeo — blokada se može postaviti samo unaprijed.");

        // The same rules the booking path enforces: the API must not accept through a direct call
        // what the schedule screen would never let an administrator do.
        var workingHours = court.WorkingHours.FirstOrDefault(w => w.DayOfWeek == dto.Date.DayOfWeek)
            ?? throw new BusinessException("Teren ne radi tog dana pa nema šta blokirati.");

        if (!SlotGrid.IsSlotRange(workingHours.OpenTime, workingHours.CloseTime, dto.StartTime, dto.EndTime))
            throw new BusinessException("Blokada mora obuhvatati cijele termine iz rasporeda terena.");

        var reserved = await _db.Reservations
            .Where(r => r.CourtId == dto.CourtId && r.Date == dto.Date &&
                        r.Status != ReservationStatus.Cancelled)
            .Select(r => new { r.StartTime, r.EndTime })
            .ToListAsync();
        if (reserved.Any(r => SlotGrid.Overlaps(r.StartTime, r.EndTime, dto.StartTime, dto.EndTime)))
            throw new BusinessException("U tom periodu već postoji rezervacija pa se ne može blokirati.");

        var existingBlocks = await _db.CourtAvailabilityBlocks
            .Where(b => b.CourtId == dto.CourtId && b.Date == dto.Date)
            .Select(b => new { b.StartTime, b.EndTime })
            .ToListAsync();
        if (existingBlocks.Any(b => SlotGrid.Overlaps(b.StartTime, b.EndTime, dto.StartTime, dto.EndTime)))
            throw new BusinessException("Taj period je već blokiran.");

        var block = new CourtAvailabilityBlock
        {
            CourtId = dto.CourtId,
            Date = dto.Date,
            StartTime = dto.StartTime,
            EndTime = dto.EndTime,
            Reason = dto.Reason,
            CreatedById = userId,
            CreatedAt = DateTime.UtcNow
        };
        _db.CourtAvailabilityBlocks.Add(block);
        await _db.SaveChangesAsync();

        return await _db.CourtAvailabilityBlocks
            .Where(b => b.Id == block.Id)
            .ProjectToType<AvailabilityBlockDto>()
            .FirstAsync();
    }

    public async Task RemoveBlockAsync(int id)
    {
        var block = await _db.CourtAvailabilityBlocks.FirstOrDefaultAsync(b => b.Id == id)
            ?? throw new NotFoundException("Blokada", id);
        block.IsDeleted = true;
        block.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
    }
}
