using CourtSide.Core.Dto;
using CourtSide.Core.Entities;
using CourtSide.Core.SearchObjects;
using CourtSide.Infrastructure;
using CourtSide.Services.Common;
using MapsterMapper;

namespace CourtSide.Services.Services;

public interface ICountryService : ICrudService<CountryDto, CountryUpsertDto, CountrySearchObject> { }

public class CountryService : BaseCrudService<Country, CountryDto, CountryUpsertDto, CountrySearchObject>, ICountryService
{
    public CountryService(DatabaseContext context, IMapper mapper) : base(context, mapper) { }

    protected override IQueryable<Country> ApplyFilter(IQueryable<Country> query, CountrySearchObject search)
    {
        if (!string.IsNullOrWhiteSpace(search.SearchTerm))
            query = query.Where(x => x.Name.Contains(search.SearchTerm));
        return query;
    }
}
