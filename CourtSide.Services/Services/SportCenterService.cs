using CourtSide.Core.Dto;
using CourtSide.Core.Entities;
using CourtSide.Core.SearchObjects;
using CourtSide.Infrastructure;
using CourtSide.Services.Common;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace CourtSide.Services.Services;

public interface ISportCenterService : ICrudService<SportCenterDto, SportCenterUpsertDto, SportCenterSearchObject> { }

public class SportCenterService : BaseCrudService<SportCenter, SportCenterDto, SportCenterUpsertDto, SportCenterSearchObject>, ISportCenterService
{
    public SportCenterService(DatabaseContext context, IMapper mapper) : base(context, mapper) { }

    protected override IQueryable<SportCenter> Include(IQueryable<SportCenter> query) => query.Include(x => x.City);

    protected override IQueryable<SportCenter> ApplyFilter(IQueryable<SportCenter> query, SportCenterSearchObject search)
    {
        if (!string.IsNullOrWhiteSpace(search.SearchTerm))
            query = query.Where(x => x.Name.Contains(search.SearchTerm) || x.Address.Contains(search.SearchTerm));
        if (search.CityId.HasValue)
            query = query.Where(x => x.CityId == search.CityId);
        return query;
    }
}
