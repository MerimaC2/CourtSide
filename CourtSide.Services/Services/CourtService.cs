using CourtSide.Core.Dto;
using CourtSide.Core.Entities;
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

    public CourtService(DatabaseContext context, IMapper mapper, ICurrentUser currentUser) : base(context, mapper)
        => _currentUser = currentUser;

    protected override IQueryable<Court> Include(IQueryable<Court> query) =>
        query.Include(x => x.Sport).Include(x => x.SportCenter).Include(x => x.Images)
             .Include(x => x.Reviews).Include(x => x.WorkingHours);

    /// <summary>A court with reservation history stays (deactivate it instead), so past bookings keep their data.</summary>
    public override async Task DeleteAsync(int id)
    {
        if (await Context.Reservations.AnyAsync(r => r.CourtId == id))
            throw new BusinessException("Teren se ne može obrisati jer ima rezervacije. Umjesto brisanja označite ga kao neaktivan.");
        await base.DeleteAsync(id);
    }

    protected override Task BeforeInsertAsync(CourtUpsertDto dto, Court entity)
    {
        ApplyWorkingHours(dto, entity);
        return Task.CompletedTask;
    }

    protected override async Task BeforeUpdateAsync(CourtUpsertDto dto, Court entity)
    {
        // The mapped entity was loaded without its children, so they are fetched here
        // before being replaced with what the form submitted.
        await Context.Entry(entity).Collection(x => x.WorkingHours).LoadAsync();
        ApplyWorkingHours(dto, entity);
    }

    /// <summary>
    /// Replaces the court's opening hours with the submitted set. Availability is derived
    /// from these, so a court saved without any would have no bookable slots; in that case
    /// a standard full-week schedule is used instead of leaving the court unusable.
    /// </summary>
    private void ApplyWorkingHours(CourtUpsertDto dto, Court entity)
    {
        var hours = dto.WorkingHours.Count > 0 ? dto.WorkingHours : DefaultWorkingHours();

        foreach (var existing in entity.WorkingHours.ToList())
            Context.Remove(existing);
        entity.WorkingHours.Clear();

        var now = DateTime.UtcNow;
        foreach (var day in hours)
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

    private static List<CourtWorkingHoursDto> DefaultWorkingHours() =>
        Enumerable.Range(0, 7)
            .Select(day => new CourtWorkingHoursDto
            {
                DayOfWeek = (DayOfWeek)day,
                OpenTime = new TimeOnly(8, 0),
                CloseTime = new TimeOnly(22, 0)
            })
            .ToList();

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
