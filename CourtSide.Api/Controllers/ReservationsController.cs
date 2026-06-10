using CourtSide.Core.Dto;
using CourtSide.Core.Dto.Base;
using CourtSide.Core.SearchObjects;
using CourtSide.Services.Services;
using CourtSide.Shared.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourtSide.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ReservationsController : ControllerBase
{
    private readonly IReservationService _service;

    public ReservationsController(IReservationService service) => _service = service;

    /// <summary>Admin: all reservations with filtering.</summary>
    [HttpGet]
    [Authorize(Roles = Roles.Admin)]
    public async Task<ActionResult<PagedResult<ReservationDto>>> Get([FromQuery] ReservationSearchObject search)
        => Ok(await _service.GetPagedAsync(search));

    /// <summary>Current user's reservations (active + history).</summary>
    [HttpGet("mine")]
    public async Task<ActionResult<PagedResult<ReservationDto>>> Mine([FromQuery] ReservationSearchObject search)
        => Ok(await _service.GetMyAsync(search));

    [HttpGet("{id:int}")]
    public async Task<ActionResult<ReservationDto>> GetById(int id)
        => Ok(await _service.GetByIdAsync(id));

    [HttpPost]
    public async Task<ActionResult<ReservationDto>> Create([FromBody] ReservationCreateDto dto)
        => Ok(await _service.CreateAsync(dto));

    [HttpPut("{id:int}/confirm")]
    [Authorize(Roles = Roles.Admin)]
    public async Task<ActionResult<ReservationDto>> Confirm(int id)
        => Ok(await _service.ConfirmAsync(id));

    [HttpPut("{id:int}/cancel")]
    public async Task<ActionResult<ReservationDto>> Cancel(int id, [FromBody] ReservationCancelDto dto)
        => Ok(await _service.CancelAsync(id, dto));
}
