using CourtSide.Core.Dto;
using CourtSide.Core.Entities;
using CourtSide.Core.Exceptions;
using CourtSide.Core.SearchObjects;
using CourtSide.Infrastructure;
using CourtSide.Services.Common;
using CourtSide.Shared.Services;
using MapsterMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;

namespace CourtSide.Services.Services;

public interface INewsService : ICrudService<NewsDto, NewsUpsertDto, NewsSearchObject>
{
    Task UploadImageAsync(int newsId, IFormFile file);
    Task<(byte[] Data, string ContentType)> GetImageAsync(int newsId);
}

public class NewsService : BaseCrudService<News, NewsDto, NewsUpsertDto, NewsSearchObject>, INewsService
{
    private readonly ICurrentUser _currentUser;

    public NewsService(DatabaseContext context, IMapper mapper, ICurrentUser currentUser)
        : base(context, mapper) => _currentUser = currentUser;

    protected override IQueryable<News> ApplyFilter(IQueryable<News> query, NewsSearchObject search)
    {
        if (!string.IsNullOrWhiteSpace(search.SearchTerm))
            query = query.Where(x => x.Title.Contains(search.SearchTerm));

        // An announcement scheduled for a future date must not reach clients before then.
        // Administrators keep seeing scheduled items so they can review and edit them.
        if (!_currentUser.IsAdmin)
        {
            var now = DateTime.UtcNow;
            query = query.Where(x => x.PublishedAt <= now);
        }

        return query.OrderByDescending(x => x.PublishedAt);
    }

    protected override Task BeforeInsertAsync(NewsUpsertDto dto, News entity)
    {
        entity.PublishedAt = dto.PublishedAt ?? DateTime.UtcNow;
        return Task.CompletedTask;
    }

    protected override Task BeforeUpdateAsync(NewsUpsertDto dto, News entity)
    {
        entity.PublishedAt = dto.PublishedAt ?? entity.PublishedAt;
        return Task.CompletedTask;
    }

    public async Task UploadImageAsync(int newsId, IFormFile file)
    {
        var news = await Context.News.FirstOrDefaultAsync(n => n.Id == newsId)
            ?? throw new NotFoundException("Obavijest", newsId);

        var (data, contentType) = await ImageValidation.ReadAndValidateAsync(file);
        news.ImageData = data;
        news.ImageContentType = contentType;
        news.UpdatedAt = DateTime.UtcNow;
        await Context.SaveChangesAsync();
    }

    public async Task<(byte[] Data, string ContentType)> GetImageAsync(int newsId)
    {
        var news = await Context.News.FirstOrDefaultAsync(n => n.Id == newsId)
            ?? throw new NotFoundException("Obavijest", newsId);

        if (news.ImageData is null || news.ImageContentType is null)
            throw new NotFoundException("Slika", newsId);

        return (news.ImageData, news.ImageContentType);
    }
}
