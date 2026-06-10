using CourtSide.Core.Dto;
using CourtSide.Core.Entities;
using CourtSide.Core.SearchObjects;
using CourtSide.Infrastructure;
using CourtSide.Services.Common;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace CourtSide.Services.Services;

public interface ICourtService : ICrudService<CourtDto, CourtUpsertDto, CourtSearchObject> { }

public class CourtService : BaseCrudService<Court, CourtDto, CourtUpsertDto, CourtSearchObject>, ICourtService
{
    public CourtService(DatabaseContext context, IMapper mapper) : base(context, mapper) { }

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
}
