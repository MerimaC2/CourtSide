using CourtSide.Core.Dto;
using CourtSide.Services.Recommender;
using CourtSide.Shared.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourtSide.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class RecommendationsController : ControllerBase
{
    private readonly IRecommenderService _service;

    public RecommendationsController(IRecommenderService service) => _service = service;

    /// <summary>Personalized court recommendations for the current user (top 2–3 by default).</summary>
    [HttpGet]
    public async Task<ActionResult<List<RecommendationDto>>> Get([FromQuery] int count = 3)
        => Ok(await _service.GetForCurrentUserAsync(count));

    /// <summary>Admin: force an immediate model re-train from the latest history (otherwise runs every 6h).</summary>
    [HttpPost("retrain")]
    [Authorize(Roles = Roles.Admin)]
    public async Task<IActionResult> Retrain()
    {
        await _service.TrainAsync();
        return NoContent();
    }
}
