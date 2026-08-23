using CourtSide.Core.Dto;
using CourtSide.Core.SearchObjects;
using CourtSide.Services.Services;
using CourtSide.Shared.Constants;
using Microsoft.AspNetCore.Authorization;
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

    /// <summary>Uploads the court's photo (admin only), replacing any previous one.</summary>
    [HttpPost("{id:int}/images")]
    [Authorize(Roles = Roles.Admin)]
    public async Task<ActionResult<int>> UploadImage(int id, IFormFile file)
        => Ok(await _courts.UploadImageAsync(id, file));

    [HttpGet("{id:int}/images/{imageId:int}")]
    public async Task<IActionResult> GetImage(int id, int imageId)
    {
        var (data, contentType) = await _courts.GetImageAsync(id, imageId);
        return File(data, contentType);
    }
}
