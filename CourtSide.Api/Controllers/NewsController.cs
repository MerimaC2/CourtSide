using CourtSide.Core.Dto;
using CourtSide.Core.SearchObjects;
using CourtSide.Services.Services;
using CourtSide.Shared.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CourtSide.Api.Controllers;

public class NewsController : BaseCrudController<NewsDto, NewsUpsertDto, NewsSearchObject>
{
    private readonly INewsService _news;

    public NewsController(INewsService service) : base(service) => _news = service;

    /// <summary>Uploads the news item's image (admin only), replacing any previous one.</summary>
    [HttpPost("{id:int}/image")]
    [Authorize(Roles = Roles.Admin)]
    public async Task<IActionResult> UploadImage(int id, IFormFile file)
    {
        await _news.UploadImageAsync(id, file);
        return NoContent();
    }

    [HttpGet("{id:int}/image")]
    public async Task<IActionResult> GetImage(int id)
    {
        var (data, contentType) = await _news.GetImageAsync(id);
        return File(data, contentType);
    }
}
