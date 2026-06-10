using CourtSide.Core.Dto;
using CourtSide.Core.SearchObjects;
using CourtSide.Services.Services;

namespace CourtSide.Api.Controllers;

public class CitiesController : BaseCrudController<CityDto, CityUpsertDto, CitySearchObject>
{
    public CitiesController(ICityService service) : base(service) { }
}
