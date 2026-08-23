using CourtSide.Core.Dto;
using CourtSide.Core.Dto.Base;
using CourtSide.Core.SearchObjects;
using CourtSide.Services.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourtSide.Api.Controllers;

/// <summary>
/// Court reviews: any authenticated user may read and post their own (business rules — own
/// completed reservation, one review per reservation — are enforced in the service). Not built
/// on <see cref="BaseCrudController{TDto,TUpsert,TSearch}"/>, whose POST is admin-only by
/// default and whose authorization attributes would still apply even if overridden.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CourtReviewsController : ControllerBase
{
    private readonly ICourtReviewService _service;

    public CourtReviewsController(ICourtReviewService service) => _service = service;

    [HttpGet]
    public async Task<ActionResult<PagedResult<CourtReviewDto>>> Get([FromQuery] CourtReviewSearchObject search)
        => Ok(await _service.GetPagedAsync(search));

    [HttpPost]
    public async Task<ActionResult<CourtReviewDto>> Create([FromBody] CourtReviewUpsertDto dto)
        => Ok(await _service.AddAsync(dto));
}
