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
            .MinimumLength(3).WithMessage("Korisničko ime mora imati najmanje 3 znaka.")
            .MaximumLength(256).WithMessage("Korisničko ime može imati najviše 256 znakova.");
        RuleFor(x => x.Email).NotEmpty().WithMessage("Email je obavezan.")
            .EmailAddress().WithMessage("Unesite ispravnu email adresu (npr. ime@domena.com).")
            .MaximumLength(256).WithMessage("Email može imati najviše 256 znakova.");
        RuleFor(x => x.Password).NotEmpty().WithMessage("Lozinka je obavezna.")
            .MinimumLength(6).WithMessage("Lozinka mora imati najmanje 6 znakova.");
        // The same limits as on the profile form, so a name accepted here can later be saved unchanged.
        RuleFor(x => x.FirstName).NotEmpty().WithMessage("Ime je obavezno.")
            .MaximumLength(100).WithMessage("Ime može imati najviše 100 znakova.");
        RuleFor(x => x.LastName).NotEmpty().WithMessage("Prezime je obavezno.")
            .MaximumLength(100).WithMessage("Prezime može imati najviše 100 znakova.");
        RuleFor(x => x.PhoneNumber).Matches(@"^[+]?[0-9\s\-]{6,20}$")
            .When(x => !string.IsNullOrWhiteSpace(x.PhoneNumber))
            .WithMessage("Unesite ispravan broj telefona (6-20 cifara, dozvoljeni +, razmak, -).");
    }
}

public class ForgotPasswordDtoValidator : AbstractValidator<ForgotPasswordDto>
{
    public ForgotPasswordDtoValidator()
    {
        RuleFor(x => x.Email).NotEmpty().WithMessage("Email je obavezan.")
            .EmailAddress().WithMessage("Unesite ispravnu email adresu (npr. ime@domena.com).");
    }
}

public class ResetPasswordDtoValidator : AbstractValidator<ResetPasswordDto>
{
    public ResetPasswordDtoValidator()
    {
        RuleFor(x => x.Email).NotEmpty().WithMessage("Email je obavezan.")
            .EmailAddress().WithMessage("Unesite ispravnu email adresu (npr. ime@domena.com).");
        RuleFor(x => x.Code).NotEmpty().WithMessage("Kod je obavezan.")
            .Matches(@"^\d{6}$").WithMessage("Kod se sastoji od 6 cifara.");
        RuleFor(x => x.NewPassword).NotEmpty().WithMessage("Nova lozinka je obavezna.")
            .MinimumLength(6).WithMessage("Lozinka mora imati najmanje 6 znakova.");
    }
}
