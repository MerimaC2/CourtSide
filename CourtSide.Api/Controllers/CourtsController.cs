using CourtSide.Core.Dto;
using CourtSide.Core.SearchObjects;
using CourtSide.Services.Services;
using Microsoft.AspNetCore.Mvc;

namespace CourtSide.Api.Controllers;

public class CourtsController : BaseCrudController<CourtDto, CourtUpsertDto, CourtSearchObject>
{
    private readonly ICourtService _courts;

    public CourtsController(ICourtService service) : base(service) => _courts = service;

    /// <summary>Logs that the current user opened this court's details (implicit recommender signal).</summary>
    [HttpPost("{id:int}/view")]
    public async Task<IActionResult> LogView(int id)
    {
        await _courts.LogViewAsync(id);
        return NoContent();
    }
}
