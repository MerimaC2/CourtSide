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
            .Map(d => d.SportCenterName, s => s.Court.SportCenter.Name)
            .Map(d => d.PaymentMethod, s => s.Payment != null ? (PaymentMethod?)s.Payment.Method : null)
            .Map(d => d.PaymentStatus, s => s.Payment != null ? (PaymentStatus?)s.Payment.Status : null)
            .Map(d => d.IsPaid, s => s.Payment != null && s.Payment.Status == PaymentStatus.Completed);

        config.NewConfig<CourtAvailabilityBlock, AvailabilityBlockDto>()
            .Map(d => d.CourtName, s => s.Court.Name);
    }
}
