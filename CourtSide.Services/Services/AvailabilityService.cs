using CourtSide.Core.Dto;
using CourtSide.Core.Entities;
using CourtSide.Core.Enumerations;
using CourtSide.Core.Exceptions;
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

    public AvailabilityService(DatabaseContext db, ICurrentUser currentUser)
    {
        _db = db;
        _currentUser = currentUser;
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

        for (var start = workingHours.OpenTime; start < workingHours.CloseTime; start = start.AddHours(1))
        {
            var end = start.AddHours(1);
            if (end > workingHours.CloseTime) break;

            var slotStart = start;
            var slotEnd = end;

            var status = SlotStatus.Available;
            if (blocks.Any(b => b.StartTime < slotEnd && slotStart < b.EndTime))
                status = SlotStatus.Blocked;
            else if (reservations.Any(r => r.StartTime < slotEnd && slotStart < r.EndTime))
                status = SlotStatus.Reserved;

            slots.Add(new AvailabilitySlotDto { StartTime = slotStart, EndTime = slotEnd, Status = status });
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

        var courtExists = await _db.Courts.AnyAsync(c => c.Id == dto.CourtId);
        if (!courtExists) throw new NotFoundException("Teren", dto.CourtId);

        if (dto.EndTime <= dto.StartTime)
            throw new BusinessException("Vrijeme završetka mora biti nakon vremena početka.");

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
