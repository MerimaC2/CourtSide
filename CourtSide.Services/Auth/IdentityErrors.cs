using Microsoft.AspNetCore.Identity;

namespace CourtSide.Services.Auth;

/// <summary>
/// Identity reports its failures in English; the rest of the API speaks Bosnian, so the codes a
/// user can actually trigger are translated here. Shared by every path that changes a password,
/// so the same failure reads the same way wherever it happens.
/// </summary>
public static class IdentityErrors
{
    public static string Describe(IdentityError error) => error.Code switch
    {
        "PasswordMismatch" => "Trenutna lozinka nije ispravna.",
        "PasswordTooShort" => "Nova lozinka je prekratka.",
        "PasswordRequiresDigit" => "Nova lozinka mora sadržavati broj.",
        "PasswordRequiresUpper" => "Nova lozinka mora sadržavati veliko slovo.",
        "PasswordRequiresLower" => "Nova lozinka mora sadržavati malo slovo.",
        "PasswordRequiresNonAlphanumeric" => "Nova lozinka mora sadržavati specijalni znak.",
        "InvalidUserName" => "Korisničko ime smije sadržavati samo slova bez kvačica, brojeve i znakove - . _ @ +.",
        "DuplicateUserName" => "Korisničko ime je već zauzeto.",
        "InvalidEmail" => "Unesite ispravnu email adresu (npr. ime@domena.com).",
        "DuplicateEmail" => "Email adresa je već registrovana.",
        _ => error.Description
    };

    public static string Describe(IEnumerable<IdentityError> errors) =>
        string.Join("\n", errors.Select(Describe));
}
