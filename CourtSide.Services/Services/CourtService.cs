using CourtSide.Core.Dto;
using CourtSide.Core.Entities;
using CourtSide.Core.Exceptions;
using CourtSide.Core.SearchObjects;
using CourtSide.Infrastructure;
using CourtSide.Services.Common;
using CourtSide.Shared.Services;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace CourtSide.Services.Services;

public interface ICourtService : ICrudService<CourtDto, CourtUpsertDto, CourtSearchObject>
{
    /// <summary>Records that the current user viewed a court — an implicit signal for the recommender.</summary>
    Task LogViewAsync(int courtId);
}

public class CourtService : BaseCrudService<Court, CourtDto, CourtUpsertDto, CourtSearchObject>, ICourtService
{
    private readonly ICurrentUser _currentUser;

    public CourtService(DatabaseContext context, IMapper mapper, ICurrentUser currentUser) : base(context, mapper)
        => _currentUser = currentUser;

    protected override IQueryable<Court> Include(IQueryable<Court> query) =>
        query.Include(x => x.Sport).Include(x => x.SportCenter);

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
}
