using CourtSide.Core.Dto.Base;
using CourtSide.Core.Entities.Base;
using CourtSide.Core.Exceptions;
using CourtSide.Core.Helpers;
using CourtSide.Core.SearchObjects;
using CourtSide.Infrastructure;
using Mapster;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace CourtSide.Services.Common;

/// <summary>
/// Generic CRUD service: paging, filtering and Mapster projection over a <see cref="DatabaseContext"/>.
/// Controllers go through services; services own the DbContext (no DbContext in controllers).
/// </summary>
public abstract class BaseCrudService<TEntity, TDto, TUpsert, TSearch> : ICrudService<TDto, TUpsert, TSearch>
    where TEntity : BaseEntity
    where TSearch : BaseSearchObject
{
    protected readonly DatabaseContext Context;
    protected readonly IMapper Mapper;

    protected BaseCrudService(DatabaseContext context, IMapper mapper)
    {
        Context = context;
        Mapper = mapper;
    }

    /// <summary>Override to add eager-loading for detail/read queries.</summary>
    protected virtual IQueryable<TEntity> Include(IQueryable<TEntity> query) => query;

    /// <summary>Override to apply search-object filtering.</summary>
    protected virtual IQueryable<TEntity> ApplyFilter(IQueryable<TEntity> query, TSearch search) => query;

    public virtual async Task<PagedResult<TDto>> GetPagedAsync(TSearch search)
    {
        var query = ApplyFilter(Context.Set<TEntity>().AsQueryable(), search);

        var total = await query.CountAsync();

        var page = search.Page < 1 ? 1 : search.Page;
        var size = Math.Clamp(search.PageSize, 1, BaseSearchObject.MaxPageSize);

        var items = await query
            .OrderByDescending(e => e.Id)
            .Skip((page - 1) * size)
            .Take(size)
            .ProjectToType<TDto>()
            .ToListAsync();

        return new PagedResult<TDto> { Items = items, TotalCount = total, Page = page, PageSize = size };
    }

    public virtual async Task<TDto> GetByIdAsync(int id)
    {
        var entity = await Include(Context.Set<TEntity>().AsQueryable())
            .FirstOrDefaultAsync(e => e.Id == id)
            ?? throw new NotFoundException(EntityNames.For(typeof(TEntity)), id);

        return Mapper.Map<TDto>(entity);
    }

    public virtual async Task<TDto> AddAsync(TUpsert dto)
    {
        ArgumentNullException.ThrowIfNull(dto);
        var entity = Mapper.Map<TEntity>(dto);
        entity.CreatedAt = DateTime.UtcNow;

        await BeforeInsertAsync(dto, entity);

        Context.Set<TEntity>().Add(entity);
        await Context.SaveChangesAsync();

        return await GetByIdAsync(entity.Id);
    }

    public virtual async Task<TDto> UpdateAsync(int id, TUpsert dto)
    {
        ArgumentNullException.ThrowIfNull(dto);
        var entity = await Context.Set<TEntity>().FirstOrDefaultAsync(e => e.Id == id)
            ?? throw new NotFoundException(EntityNames.For(typeof(TEntity)), id);

        Mapper.Map(dto, entity);
        entity.UpdatedAt = DateTime.UtcNow;

        await BeforeUpdateAsync(dto, entity);

        await Context.SaveChangesAsync();

        return await GetByIdAsync(entity.Id);
    }

    public virtual async Task DeleteAsync(int id)
    {
        var entity = await Context.Set<TEntity>().FirstOrDefaultAsync(e => e.Id == id)
            ?? throw new NotFoundException(EntityNames.For(typeof(TEntity)), id);

        entity.IsDeleted = true;
        entity.UpdatedAt = DateTime.UtcNow;
        await Context.SaveChangesAsync();
    }

    protected virtual Task BeforeInsertAsync(TUpsert dto, TEntity entity) => Task.CompletedTask;
    protected virtual Task BeforeUpdateAsync(TUpsert dto, TEntity entity) => Task.CompletedTask;
}
