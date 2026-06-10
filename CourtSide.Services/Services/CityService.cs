using CourtSide.Core.Dto;
using CourtSide.Core.Entities;
using CourtSide.Core.SearchObjects;
using CourtSide.Infrastructure;
using CourtSide.Services.Common;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace CourtSide.Services.Services;

public interface ICityService : ICrudService<CityDto, CityUpsertDto, CitySearchObject> { }

public class CityService : BaseCrudService<City, CityDto, CityUpsertDto, CitySearchObject>, ICityService
{
    public CityService(DatabaseContext context, IMapper mapper) : base(context, mapper) { }

    protected override IQueryable<City> Include(IQueryable<City> query) => query.Include(x => x.Country);

    protected override IQueryable<City> ApplyFilter(IQueryable<City> query, CitySearchObject search)
    {
        if (!string.IsNullOrWhiteSpace(search.SearchTerm))
            query = query.Where(x => x.Name.Contains(search.SearchTerm));
        if (search.CountryId.HasValue)
            query = query.Where(x => x.CountryId == search.CountryId);
        return query;
    }
}
