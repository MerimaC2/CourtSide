using CourtSide.Core.Dto;
using CourtSide.Core.Entities;
using CourtSide.Core.Exceptions;
using CourtSide.Core.SearchObjects;
using CourtSide.Infrastructure;
using CourtSide.Services.Common;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace CourtSide.Services.Services;

public interface ICountryService : ICrudService<CountryDto, CountryUpsertDto, CountrySearchObject> { }

public class CountryService : BaseCrudService<Country, CountryDto, CountryUpsertDto, CountrySearchObject>, ICountryService
{
    public CountryService(DatabaseContext context, IMapper mapper) : base(context, mapper) { }

    /// <summary>Reference data in use must not disappear from under the records that point at it.</summary>
    public override async Task DeleteAsync(int id)
    {
        if (await Context.Cities.AnyAsync(c => c.CountryId == id))
            throw new BusinessException("Država se ne može obrisati jer postoje gradovi koji joj pripadaju.");
        await base.DeleteAsync(id);
    }

    protected override IQueryable<Country> ApplyFilter(IQueryable<Country> query, CountrySearchObject search)
    {
        if (!string.IsNullOrWhiteSpace(search.SearchTerm))
            query = query.Where(x => x.Name.Contains(search.SearchTerm));
        return query;
    }
}
