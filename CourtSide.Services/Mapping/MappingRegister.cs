using CourtSide.Core.Dto;
using CourtSide.Core.Entities;
using CourtSide.Core.Enumerations;
using Mapster;

namespace CourtSide.Services.Mapping;

/// <summary>Mapster mappings that need more than convention-based flattening.</summary>
public class MappingRegister : IRegister
{
    public void Register(TypeAdapterConfig config)
    {
        config.NewConfig<Reservation, ReservationDto>()
            .Map(d => d.ClientName, s => s.Client.FirstName + " " + s.Client.LastName)
            .Map(d => d.CourtName, s => s.Court.Name)
            .Map(d => d.CourtIsActive, s => s.Court.IsActive)
            .Map(d => d.SportCenterName, s => s.Court.SportCenter.Name)
            .Map(d => d.PaymentMethod, s => s.Payment != null ? (PaymentMethod?)s.Payment.Method : null)
            .Map(d => d.PaymentStatus, s => s.Payment != null ? (PaymentStatus?)s.Payment.Status : null)
            .Map(d => d.IsPaid, s => s.Payment != null && s.Payment.Status == PaymentStatus.Completed)
            .Map(d => d.HasReview, s => s.Reviews.Any());

        config.NewConfig<CourtAvailabilityBlock, AvailabilityBlockDto>()
            .Map(d => d.CourtName, s => s.Court.Name);

        config.NewConfig<Court, CourtDto>()
            .Map(d => d.SportCenterAddress, s => s.SportCenter.Address)
            .Map(d => d.CityName, s => s.SportCenter.City.Name)
            .Map(d => d.PrimaryImageId,
                s => s.Images.Where(i => i.IsPrimary).Select(i => (int?)i.Id).FirstOrDefault())
            .Map(d => d.AverageRating,
                s => s.Reviews.Any() ? (double?)s.Reviews.Average(r => r.Rating) : null)
            .Map(d => d.ReviewCount, s => s.Reviews.Count)
            .Map(d => d.WorkingHours, s => s.WorkingHours.OrderBy(w => w.DayOfWeek));

        // The court's opening hours are replaced explicitly in CourtService, so the
        // incoming collection must not also be mapped onto the entity.
        config.NewConfig<CourtUpsertDto, Court>()
            .Ignore(d => d.WorkingHours);

        config.NewConfig<News, NewsDto>()
            .Map(d => d.HasImage, s => s.ImageData != null);

        config.NewConfig<CourtReview, CourtReviewDto>()
            .Map(d => d.CourtName, s => s.Court.Name)
            .Map(d => d.UserName, s => s.User.FirstName + " " + s.User.LastName);
    }
}
