using CourtSide.Core.Dto;
using CourtSide.Core.SearchObjects;
using CourtSide.Services.Services;

namespace CourtSide.Api.Controllers;

public class CourtsController : BaseCrudController<CourtDto, CourtUpsertDto, CourtSearchObject>
{
    public CourtsController(ICourtService service) : base(service) { }
}
