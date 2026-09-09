using CourtSide.Core.SearchObjects;
using CourtSide.Core.Dto;
using FluentValidation;

namespace CourtSide.Services.Validation;

public class ReservationCreateDtoValidator : AbstractValidator<ReservationCreateDto>
{
    public ReservationCreateDtoValidator()
    {
        RuleFor(x => x.CourtId).GreaterThan(0).WithMessage("Odaberite teren.");
        RuleFor(x => x.ContactName).NotEmpty().WithMessage("Ime i prezime su obavezni.")
            .MaximumLength(150);
        RuleFor(x => x.ContactPhone).NotEmpty().WithMessage("Broj telefona je obavezan.")
            .Matches(@"^[+]?[0-9\s\-]{6,20}$")
            .WithMessage("Unesite ispravan broj telefona (6-20 cifara, dozvoljeni +, razmak, -).");
        RuleFor(x => x.EndTime).GreaterThan(x => x.StartTime)
            .WithMessage("Vrijeme završetka mora biti nakon vremena početka.");
    }
}

public class AvailabilityBlockUpsertDtoValidator : AbstractValidator<AvailabilityBlockUpsertDto>
{
    public AvailabilityBlockUpsertDtoValidator()
    {
        RuleFor(x => x.CourtId).GreaterThan(0).WithMessage("Odaberite teren.");
        RuleFor(x => x.EndTime).GreaterThan(x => x.StartTime)
            .WithMessage("Vrijeme završetka mora biti nakon vremena početka.");
    }
}

public class ReservationSearchObjectValidator : AbstractValidator<ReservationSearchObject>
{
    public ReservationSearchObjectValidator()
    {
        // A reversed range matches nothing, so the list came back empty as if there were no
        // reservations at all.
        RuleFor(x => x.DateTo).GreaterThanOrEqualTo(x => x.DateFrom!.Value)
            .When(x => x.DateFrom.HasValue && x.DateTo.HasValue)
            .WithMessage("Datum „od“ ne može biti poslije datuma „do“.");
    }
}
