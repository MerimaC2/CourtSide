using CourtSide.Core.Dto.Base;
using CourtSide.Core.SearchObjects;
using CourtSide.Services.Common;
using CourtSide.Shared.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourtSide.Api.Controllers;

/// <summary>
/// Generic CRUD controller. Reads are open to any authenticated user; writes require the Admin role.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public abstract class BaseCrudController<TDto, TUpsert, TSearch> : ControllerBase
    where TSearch : BaseSearchObject
{
    protected readonly ICrudService<TDto, TUpsert, TSearch> Service;

    protected BaseCrudController(ICrudService<TDto, TUpsert, TSearch> service) => Service = service;

    [HttpGet]
    public virtual async Task<ActionResult<PagedResult<TDto>>> Get([FromQuery] TSearch search)
        => Ok(await Service.GetPagedAsync(search));

    [HttpGet("{id:int}")]
    public virtual async Task<ActionResult<TDto>> GetById(int id)
        => Ok(await Service.GetByIdAsync(id));

    [HttpPost]
    [Authorize(Roles = Roles.Admin)]
    public virtual async Task<ActionResult<TDto>> Create([FromBody] TUpsert dto)
        => Ok(await Service.AddAsync(dto));

    [HttpPut("{id:int}")]
    [Authorize(Roles = Roles.Admin)]
    public virtual async Task<ActionResult<TDto>> Update(int id, [FromBody] TUpsert dto)
        => Ok(await Service.UpdateAsync(id, dto));

    [HttpDelete("{id:int}")]
    [Authorize(Roles = Roles.Admin)]
    public virtual async Task<IActionResult> Delete(int id)
    {
        await Service.DeleteAsync(id);
        return NoContent();
    }
}
