using CourtSide.Core.Dto;
using FluentValidation;

namespace CourtSide.Services.Validation;

public class ProfileUpdateDtoValidator : AbstractValidator<ProfileUpdateDto>
{
    public ProfileUpdateDtoValidator()
    {
        RuleFor(x => x.FirstName).NotEmpty().WithMessage("Ime je obavezno.")
            .MaximumLength(100).WithMessage("Ime može imati najviše 100 znakova.");
        RuleFor(x => x.LastName).NotEmpty().WithMessage("Prezime je obavezno.")
            .MaximumLength(100).WithMessage("Prezime može imati najviše 100 znakova.");
        RuleFor(x => x.PhoneNumber).Matches(@"^[+]?[0-9\s\-]{6,20}$")
            .When(x => !string.IsNullOrWhiteSpace(x.PhoneNumber))
            .WithMessage("Unesite ispravan broj telefona (6-20 cifara, dozvoljeni +, razmak, -).");
    }
}

public class ChangePasswordDtoValidator : AbstractValidator<ChangePasswordDto>
{
    public ChangePasswordDtoValidator()
    {
        RuleFor(x => x.CurrentPassword).NotEmpty().WithMessage("Trenutna lozinka je obavezna.");
        RuleFor(x => x.NewPassword).NotEmpty().WithMessage("Nova lozinka je obavezna.")
            .MinimumLength(6).WithMessage("Lozinka mora imati najmanje 6 znakova.")
            .NotEqual(x => x.CurrentPassword).WithMessage("Nova lozinka mora biti različita od trenutne.");
    }
}
