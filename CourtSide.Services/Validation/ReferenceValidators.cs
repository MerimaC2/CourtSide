using CourtSide.Core.Dto;
using FluentValidation;

namespace CourtSide.Services.Validation;

public class CountryUpsertDtoValidator : AbstractValidator<CountryUpsertDto>
{
    public CountryUpsertDtoValidator()
    {
        RuleFor(x => x.Name).NotEmpty().WithMessage("Naziv države je obavezan.")
            .MaximumLength(100).WithMessage("Naziv može imati najviše 100 znakova.");
        RuleFor(x => x.IsoCode).MaximumLength(3)
            .WithMessage("ISO kod može imati najviše 3 znaka.");
    }
}

public class CityUpsertDtoValidator : AbstractValidator<CityUpsertDto>
{
    public CityUpsertDtoValidator()
    {
        RuleFor(x => x.Name).NotEmpty().WithMessage("Naziv grada je obavezan.")
            .MaximumLength(100).WithMessage("Naziv može imati najviše 100 znakova.");
        RuleFor(x => x.CountryId).GreaterThan(0).WithMessage("Odaberite državu.");
    }
}

public class SportUpsertDtoValidator : AbstractValidator<SportUpsertDto>
{
    public SportUpsertDtoValidator()
    {
        RuleFor(x => x.Name).NotEmpty().WithMessage("Naziv sporta je obavezan.")
            .MaximumLength(80).WithMessage("Naziv može imati najviše 80 znakova.");
    }
}
