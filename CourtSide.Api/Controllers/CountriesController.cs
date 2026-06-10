using CourtSide.Core.Dto;
using CourtSide.Core.SearchObjects;
using CourtSide.Services.Services;

namespace CourtSide.Api.Controllers;

public class CountriesController : BaseCrudController<CountryDto, CountryUpsertDto, CountrySearchObject>
{
    public CountriesController(ICountryService service) : base(service) { }
}
