using CourtSide.Core.Dto.Base;
using CourtSide.Core.SearchObjects;

namespace CourtSide.Services.Common;

public interface ICrudService<TDto, TUpsert, TSearch>
    where TSearch : BaseSearchObject
{
    Task<PagedResult<TDto>> GetPagedAsync(TSearch search);
    Task<TDto> GetByIdAsync(int id);
    Task<TDto> AddAsync(TUpsert dto);
    Task<TDto> UpdateAsync(int id, TUpsert dto);
    Task DeleteAsync(int id);
}
