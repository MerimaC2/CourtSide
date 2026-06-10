using CourtSide.Core.Dto;
using CourtSide.Core.SearchObjects;
using CourtSide.Services.Services;

namespace CourtSide.Api.Controllers;

public class SportCentersController : BaseCrudController<SportCenterDto, SportCenterUpsertDto, SportCenterSearchObject>
{
    public SportCentersController(ISportCenterService service) : base(service) { }
}
