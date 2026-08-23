using CourtSide.Core.Dto;
using CourtSide.Services.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourtSide.Api.Controllers;

/// <summary>The current authenticated user's own profile — never operates on other users' data.</summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ProfileController : ControllerBase
{
    private readonly IProfileService _service;

    public ProfileController(IProfileService service) => _service = service;

    [HttpGet]
    public async Task<ActionResult<ProfileDto>> Get() => Ok(await _service.GetAsync());

    [HttpPut]
    public async Task<ActionResult<ProfileDto>> Update([FromBody] ProfileUpdateDto dto)
        => Ok(await _service.UpdateAsync(dto));

    [HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordDto dto)
    {
        await _service.ChangePasswordAsync(dto);
        return NoContent();
    }

    [HttpPost("image")]
    public async Task<IActionResult> UploadImage(IFormFile file)
    {
        await _service.UploadImageAsync(file);
        return NoContent();
    }

    [HttpGet("image")]
    public async Task<IActionResult> GetImage()
    {
        var image = await _service.GetImageAsync();
        if (image is null) return NotFound();
        return File(image.Value.Data, image.Value.ContentType);
    }
}
