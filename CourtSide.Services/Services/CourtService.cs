using CourtSide.Core.Dto;
using CourtSide.Core.Entities;
using CourtSide.Core.Enumerations;
using CourtSide.Core.Exceptions;
using CourtSide.Core.SearchObjects;
using CourtSide.Infrastructure;
using CourtSide.Services.Common;
using CourtSide.Shared.Services;
using MapsterMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;

namespace CourtSide.Services.Services;

public interface ICourtService : ICrudService<CourtDto, CourtUpsertDto, CourtSearchObject>
{
    /// <summary>Records that the current user viewed a court — an implicit signal for the recommender.</summary>
    Task LogViewAsync(int courtId);

    /// <summary>Uploads a new photo for the court and makes it the primary image, replacing any previous one.</summary>
    Task<int> UploadImageAsync(int courtId, IFormFile file);

    Task<(byte[] Data, string ContentType)> GetImageAsync(int courtId, int imageId);
}

public class CourtService : BaseCrudService<Court, CourtDto, CourtUpsertDto, CourtSearchObject>, ICourtService
{
    private readonly ICurrentUser _currentUser;
    private readonly IAppClock _clock;

    public CourtService(DatabaseContext context, IMapper mapper, ICurrentUser currentUser, IAppClock clock)
        : base(context, mapper)
    {
        _currentUser = currentUser;
        _clock = clock;
    }

    protected override IQueryable<Court> Include(IQueryable<Court> query) =>
        query.Include(x => x.Sport).Include(x => x.SportCenter).ThenInclude(s => s.City)
             .Include(x => x.Images).Include(x => x.Reviews).Include(x => x.WorkingHours);

    /// <summary>A court with reservation history stays (deactivate it instead), so past bookings keep their data.</summary>
    public override async Task DeleteAsync(int id)
    {
        if (await Context.Reservations.AnyAsync(r => r.CourtId == id))
            throw new BusinessException("Teren se ne može obrisati jer ima rezervacije. Umjesto brisanja označite ga kao neaktivan.");
        await base.DeleteAsync(id);
    }

    protected override async Task BeforeInsertAsync(CourtUpsertDto dto, Court entity)
    {
        await EnsureReferencesAsync(dto);
        ApplyWorkingHours(dto, entity);
    }

    protected override async Task BeforeUpdateAsync(CourtUpsertDto dto, Court entity)
    {
        await EnsureReferencesAsync(dto);
        await EnsureNoBookingsOutsideAsync(entity.Id, dto.WorkingHours!);

        // The mapped entity was loaded without its children, so they are fetched here
        // before being replaced with what the form submitted.
        await Context.Entry(entity).Collection(x => x.WorkingHours).LoadAsync();
        ApplyWorkingHours(dto, entity);
    }

    /// <summary>The referenced records are checked here so the caller is told which one is missing;
    /// left to the database, the same case surfaces as an unreadable constraint violation.</summary>
    private async Task EnsureReferencesAsync(CourtUpsertDto dto)
    {
        if (!await Context.Sports.AnyAsync(s => s.Id == dto.SportId))
            throw new NotFoundException("Sport", dto.SportId);
        if (!await Context.SportCenters.AnyAsync(c => c.Id == dto.SportCenterId))
            throw new NotFoundException("Sportski centar", dto.SportCenterId);
    }

    /// <summary>
    /// Refuses a schedule change that would strand existing bookings. Closing a weekday or
    /// narrowing its hours does not cancel anything, so without this the client would keep a
    /// confirmed booking for a time the court is now closed, while the slot itself disappears
    /// from the schedule. The administrator has to cancel those reservations first, the same way
    /// reference data in use cannot simply be deleted.
    /// </summary>
    private async Task EnsureNoBookingsOutsideAsync(int courtId, List<CourtWorkingHoursDto> newHours)
    {
        var today = _clock.Today;
        var timeOfDay = _clock.LocalTimeOfDay;

        var upcoming = await Context.Reservations
            .Where(r => r.CourtId == courtId &&
                        (r.Status == ReservationStatus.Pending || r.Status == ReservationStatus.Confirmed) &&
                        (r.Date > today || (r.Date == today && r.StartTime > timeOfDay)))
            .Select(r => new { r.Date, r.StartTime, r.EndTime })
            .ToListAsync();

        var stranded = upcoming.Any(r =>
        {
            var day = newHours.FirstOrDefault(h => h.DayOfWeek == r.Date.DayOfWeek);
            return day is null || r.StartTime < day.OpenTime || r.EndTime > day.CloseTime;
        });

        if (!stranded) return;

        // Deliberately without a list: there can be many, and the administrator finds them in the
        // reservations screen anyway.
        throw new BusinessException(
            "Postoje aktivne rezervacije izvan novog rasporeda. Otkažite ih prije izmjene radnog vremena.");
    }

    /// <summary>
    /// Replaces the court's opening hours with exactly the submitted set. An empty set means the
    /// court is closed and has no bookable slots, as <see cref="CourtUpsertDto.WorkingHours"/>
    /// documents; substituting a default schedule here would silently rewrite the caller's intent,
    /// which is particularly dangerous on edit. The validator has already rejected a missing set.
    /// </summary>
    private void ApplyWorkingHours(CourtUpsertDto dto, Court entity)
    {
        foreach (var existing in entity.WorkingHours.ToList())
            Context.Remove(existing);
        entity.WorkingHours.Clear();

        var now = DateTime.UtcNow;
        foreach (var day in dto.WorkingHours!)
        {
            if (day.CloseTime <= day.OpenTime)
                throw new BusinessException("Vrijeme zatvaranja mora biti nakon vremena otvaranja.");

            entity.WorkingHours.Add(new CourtWorkingHours
            {
                DayOfWeek = day.DayOfWeek,
                OpenTime = day.OpenTime,
                CloseTime = day.CloseTime,
                CreatedAt = now
            });
        }
    }


    protected override IQueryable<Court> ApplyFilter(IQueryable<Court> query, CourtSearchObject search)
    {
        if (!string.IsNullOrWhiteSpace(search.SearchTerm))
            query = query.Where(x => x.Name.Contains(search.SearchTerm));
        if (search.SportId.HasValue)
            query = query.Where(x => x.SportId == search.SportId);
        if (search.SportCenterId.HasValue)
            query = query.Where(x => x.SportCenterId == search.SportCenterId);
        if (search.CityId.HasValue)
            query = query.Where(x => x.SportCenter.CityId == search.CityId);
        if (search.IsActive.HasValue)
            query = query.Where(x => x.IsActive == search.IsActive);
        if (search.MaxPricePerHour.HasValue)
            query = query.Where(x => x.PricePerHour <= search.MaxPricePerHour);
        return query;
    }

    public async Task LogViewAsync(int courtId)
    {
        var userId = _currentUser.UserId ?? throw new BusinessException("Niste prijavljeni.");

        if (!await Context.Courts.AnyAsync(c => c.Id == courtId))
            throw new NotFoundException("Teren", courtId);

        var now = DateTime.UtcNow;
        Context.CourtViewLogs.Add(new CourtViewLog
        {
            UserId = userId,
            CourtId = courtId,
            ViewedAt = now,
            CreatedAt = now
        });
        await Context.SaveChangesAsync();
    }

    public async Task<int> UploadImageAsync(int courtId, IFormFile file)
    {
        if (!await Context.Courts.AnyAsync(c => c.Id == courtId))
            throw new NotFoundException("Teren", courtId);

        var (data, contentType) = await ImageValidation.ReadAndValidateAsync(file);

        // A court has a single representative photo: replace whatever was there before.
        var existing = await Context.CourtImages.Where(i => i.CourtId == courtId).ToListAsync();
        Context.CourtImages.RemoveRange(existing);

        var image = new CourtImage
        {
            CourtId = courtId,
            ImageData = data,
            ContentType = contentType,
            IsPrimary = true,
            CreatedAt = DateTime.UtcNow
        };
        Context.CourtImages.Add(image);
        await Context.SaveChangesAsync();

        return image.Id;
    }

    public async Task<(byte[] Data, string ContentType)> GetImageAsync(int courtId, int imageId)
    {
        var image = await Context.CourtImages
            .FirstOrDefaultAsync(i => i.Id == imageId && i.CourtId == courtId)
            ?? throw new NotFoundException("Slika", imageId);

        return (image.ImageData, image.ContentType);
    }
}
