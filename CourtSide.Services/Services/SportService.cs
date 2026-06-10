using CourtSide.Core.Dto;
using CourtSide.Core.Entities;
using CourtSide.Core.SearchObjects;
using CourtSide.Infrastructure;
using CourtSide.Services.Common;
using MapsterMapper;

namespace CourtSide.Services.Services;

public interface ISportService : ICrudService<SportDto, SportUpsertDto, SportSearchObject> { }

public class SportService : BaseCrudService<Sport, SportDto, SportUpsertDto, SportSearchObject>, ISportService
{
    public SportService(DatabaseContext context, IMapper mapper) : base(context, mapper) { }

    protected override IQueryable<Sport> ApplyFilter(IQueryable<Sport> query, SportSearchObject search)
    {
        if (!string.IsNullOrWhiteSpace(search.SearchTerm))
            query = query.Where(x => x.Name.Contains(search.SearchTerm));
        return query;
    }
}
