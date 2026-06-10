using CourtSide.Core.Dto;
using FluentValidation;

namespace CourtSide.Services.Validation;

public class LoginRequestValidator : AbstractValidator<LoginRequest>
{
    public LoginRequestValidator()
    {
        RuleFor(x => x.Username).NotEmpty().WithMessage("Korisničko ime je obavezno.");
        RuleFor(x => x.Password).NotEmpty().WithMessage("Lozinka je obavezna.");
    }
}

public class RegisterRequestValidator : AbstractValidator<RegisterRequest>
{
    public RegisterRequestValidator()
    {
        RuleFor(x => x.Username).NotEmpty().WithMessage("Korisničko ime je obavezno.")
            .MinimumLength(3).WithMessage("Korisničko ime mora imati najmanje 3 znaka.");
        RuleFor(x => x.Email).NotEmpty().WithMessage("Email je obavezan.")
            .EmailAddress().WithMessage("Unesite ispravnu email adresu (npr. ime@domena.com).");
        RuleFor(x => x.Password).NotEmpty().WithMessage("Lozinka je obavezna.")
            .MinimumLength(6).WithMessage("Lozinka mora imati najmanje 6 znakova.");
        RuleFor(x => x.FirstName).NotEmpty().WithMessage("Ime je obavezno.");
        RuleFor(x => x.LastName).NotEmpty().WithMessage("Prezime je obavezno.");
        RuleFor(x => x.PhoneNumber).Matches(@"^[+]?[0-9\s\-]{6,20}$")
            .When(x => !string.IsNullOrWhiteSpace(x.PhoneNumber))
            .WithMessage("Unesite ispravan broj telefona (6-20 cifara, dozvoljeni +, razmak, -).");
    }
}
