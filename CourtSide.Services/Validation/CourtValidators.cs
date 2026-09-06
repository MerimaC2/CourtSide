using CourtSide.Core.Dto;
using FluentValidation;

namespace CourtSide.Services.Validation;

public class SportCenterUpsertDtoValidator : AbstractValidator<SportCenterUpsertDto>
{
    public SportCenterUpsertDtoValidator()
    {
        RuleFor(x => x.Name).NotEmpty().WithMessage("Naziv centra je obavezan.")
            .MaximumLength(150);
        RuleFor(x => x.Address).NotEmpty().WithMessage("Adresa je obavezna.")
            .MaximumLength(250);
        RuleFor(x => x.CityId).GreaterThan(0).WithMessage("Odaberite grad.");
        RuleFor(x => x.Latitude).InclusiveBetween(-90, 90)
            .When(x => x.Latitude.HasValue).WithMessage("Geografska širina mora biti između -90 i 90.");
        RuleFor(x => x.Longitude).InclusiveBetween(-180, 180)
            .When(x => x.Longitude.HasValue).WithMessage("Geografska dužina mora biti između -180 i 180.");
    }
}

public class CourtUpsertDtoValidator : AbstractValidator<CourtUpsertDto>
{
    public CourtUpsertDtoValidator()
    {
        RuleFor(x => x.Name).NotEmpty().WithMessage("Naziv terena je obavezan.")
            .MaximumLength(120).WithMessage("Naziv može imati najviše 120 znakova.");
        RuleFor(x => x.SportId).GreaterThan(0).WithMessage("Odaberite sport.");
        RuleFor(x => x.SportCenterId).GreaterThan(0).WithMessage("Odaberite sportski centar.");
        RuleFor(x => x.PricePerHour).GreaterThan(0).WithMessage("Cijena po satu mora biti veća od 0.");

        RuleForEach(x => x.WorkingHours)
            .Must(day => day.CloseTime > day.OpenTime)
            .WithMessage("Vrijeme zatvaranja mora biti nakon vremena otvaranja.");

        // Availability reads one row per weekday while the occupancy report sums them all, so a
        // duplicated day would make the same court produce two different answers.
        RuleFor(x => x.WorkingHours)
            .Must(hours => hours.Select(h => h.DayOfWeek).Distinct().Count() == hours.Count)
            .WithMessage("Radno vrijeme može imati samo jedan unos po danu u sedmici.");
    }
}
