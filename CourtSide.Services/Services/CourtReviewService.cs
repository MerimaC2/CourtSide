using CourtSide.Core.Dto;
using CourtSide.Core.Entities;
using CourtSide.Core.Enumerations;
using CourtSide.Core.Exceptions;
using CourtSide.Core.SearchObjects;
using CourtSide.Infrastructure;
using CourtSide.Services.Common;
using CourtSide.Shared.Services;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace CourtSide.Services.Services;

public interface ICourtReviewService : ICrudService<CourtReviewDto, CourtReviewUpsertDto, CourtReviewSearchObject>
{
}

public class CourtReviewService : BaseCrudService<CourtReview, CourtReviewDto, CourtReviewUpsertDto, CourtReviewSearchObject>,
    ICourtReviewService
{
    private readonly ICurrentUser _currentUser;

    public CourtReviewService(DatabaseContext context, IMapper mapper, ICurrentUser currentUser) : base(context, mapper)
        => _currentUser = currentUser;

    protected override IQueryable<CourtReview> Include(IQueryable<CourtReview> query) =>
        query.Include(x => x.Court).Include(x => x.User);

    protected override IQueryable<CourtReview> ApplyFilter(IQueryable<CourtReview> query, CourtReviewSearchObject search)
    {
        if (search.CourtId.HasValue)
            query = query.Where(x => x.CourtId == search.CourtId);
        return query.OrderByDescending(x => x.CreatedAt);
    }

    protected override async Task BeforeInsertAsync(CourtReviewUpsertDto dto, CourtReview entity)
    {
        var userId = _currentUser.UserId ?? throw new BusinessException("Niste prijavljeni.");

        var reservation = await Context.Reservations.FirstOrDefaultAsync(r => r.Id == dto.ReservationId)
            ?? throw new NotFoundException("Rezervacija", dto.ReservationId);

        if (reservation.ClientId != userId)
            throw new ForbiddenException("Nemate pristup ovoj rezervaciji.");

        if (reservation.Status != ReservationStatus.Completed)
            throw new BusinessException("Recenzija je moguća samo za završenu rezervaciju.");

        var alreadyReviewed = await Context.CourtReviews.AnyAsync(r => r.ReservationId == dto.ReservationId);
        if (alreadyReviewed)
            throw new BusinessException("Rezervacija je već ocijenjena.");

        entity.CourtId = reservation.CourtId;
        entity.UserId = userId;
    }
}
