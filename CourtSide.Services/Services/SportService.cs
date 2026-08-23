using CourtSide.Core.Dto;
using CourtSide.Core.Entities;
using CourtSide.Core.Exceptions;
using CourtSide.Core.SearchObjects;
using CourtSide.Infrastructure;
using CourtSide.Services.Common;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace CourtSide.Services.Services;

public interface ISportService : ICrudService<SportDto, SportUpsertDto, SportSearchObject> { }

public class SportService : BaseCrudService<Sport, SportDto, SportUpsertDto, SportSearchObject>, ISportService
{
    public SportService(DatabaseContext context, IMapper mapper) : base(context, mapper) { }

    /// <summary>Reference data in use must not disappear from under the records that point at it.</summary>
    public override async Task DeleteAsync(int id)
    {
        if (await Context.Courts.AnyAsync(c => c.SportId == id))
            throw new BusinessException("Sport se ne može obrisati jer postoje tereni koji ga koriste.");
        await base.DeleteAsync(id);
    }

    protected override IQueryable<Sport> ApplyFilter(IQueryable<Sport> query, SportSearchObject search)
    {
        if (!string.IsNullOrWhiteSpace(search.SearchTerm))
            query = query.Where(x => x.Name.Contains(search.SearchTerm));
        return query;
    }
}
