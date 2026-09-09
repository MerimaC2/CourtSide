using CourtSide.Core.Dto;
using CourtSide.Core.Entities;
using CourtSide.Core.Exceptions;
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

    /// <summary>Reference data in use must not disappear from under the records that point at it.</summary>
    public override async Task DeleteAsync(int id)
    {
        if (await Context.Courts.AnyAsync(c => c.SportCenterId == id))
            throw new BusinessException("Sportski centar se ne može obrisati jer postoje tereni koji mu pripadaju.");
        await base.DeleteAsync(id);
    }

    protected override Task BeforeInsertAsync(SportCenterUpsertDto dto, SportCenter entity) => EnsureCityAsync(dto.CityId);

    protected override Task BeforeUpdateAsync(SportCenterUpsertDto dto, SportCenter entity) => EnsureCityAsync(dto.CityId);

    /// <summary>See <see cref="CityService"/>: a missing reference is reported as such.</summary>
    private async Task EnsureCityAsync(int cityId)
    {
        if (!await Context.Cities.AnyAsync(c => c.Id == cityId))
            throw new NotFoundException("Grad", cityId);
    }

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
