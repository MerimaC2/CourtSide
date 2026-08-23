using CourtSide.Core.Dto;
using CourtSide.Core.Entities;
using CourtSide.Core.Exceptions;
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

    /// <summary>Reference data in use must not disappear from under the records that point at it.</summary>
    public override async Task DeleteAsync(int id)
    {
        if (await Context.SportCenters.AnyAsync(s => s.CityId == id))
            throw new BusinessException("Grad se ne može obrisati jer postoje sportski centri koji ga koriste.");
        await base.DeleteAsync(id);
    }

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
