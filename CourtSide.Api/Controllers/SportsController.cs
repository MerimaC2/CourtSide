using CourtSide.Core.Dto;
using CourtSide.Core.SearchObjects;
using CourtSide.Services.Services;

namespace CourtSide.Api.Controllers;

public class SportsController : BaseCrudController<SportDto, SportUpsertDto, SportSearchObject>
{
    public SportsController(ISportService service) : base(service) { }
}
