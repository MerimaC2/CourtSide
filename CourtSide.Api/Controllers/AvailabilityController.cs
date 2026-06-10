using CourtSide.Core.Dto;
using CourtSide.Services.Services;
using CourtSide.Shared.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourtSide.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class AvailabilityController : ControllerBase
{
    private readonly IAvailabilityService _service;

    public AvailabilityController(IAvailabilityService service) => _service = service;

    /// <summary>Free/reserved/blocked time slots for a court on a date.</summary>
    [HttpGet("slots")]
    public async Task<ActionResult<List<AvailabilitySlotDto>>> Slots([FromQuery] int courtId, [FromQuery] DateOnly date)
        => Ok(await _service.GetSlotsAsync(courtId, date));

    [HttpGet("blocks")]
    [Authorize(Roles = Roles.Admin)]
    public async Task<ActionResult<List<AvailabilityBlockDto>>> Blocks([FromQuery] int courtId, [FromQuery] DateOnly date)
        => Ok(await _service.GetBlocksAsync(courtId, date));

    [HttpPost("blocks")]
    [Authorize(Roles = Roles.Admin)]
    public async Task<ActionResult<AvailabilityBlockDto>> AddBlock([FromBody] AvailabilityBlockUpsertDto dto)
        => Ok(await _service.AddBlockAsync(dto));

    [HttpDelete("blocks/{id:int}")]
    [Authorize(Roles = Roles.Admin)]
    public async Task<IActionResult> RemoveBlock(int id)
    {
        await _service.RemoveBlockAsync(id);
        return NoContent();
    }
}
