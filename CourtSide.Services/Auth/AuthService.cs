using CourtSide.Core.Dto;
using CourtSide.Core.Entities.Identity;
using CourtSide.Core.Exceptions;
using CourtSide.Shared.Constants;
using CourtSide.Shared.Messages;
using CourtSide.Shared.Messaging;
using CourtSide.Shared.Services;
using Microsoft.AspNetCore.Identity;

namespace CourtSide.Services.Auth;

public interface IAuthService
{
    Task<AuthResponse> LoginAsync(LoginRequest request);
    Task<AuthResponse> RegisterAsync(RegisterRequest request);
    Task LogoutAsync();

    /// <summary>Emails a one-time code to the address, if it belongs to an account.</summary>
    Task RequestPasswordResetAsync(ForgotPasswordDto dto);

    /// <summary>Sets a new password once the emailed code checks out.</summary>
    Task ResetPasswordAsync(ResetPasswordDto dto);
}

public class AuthService : IAuthService
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly ITokenService _tokenService;
    private readonly ITokenRevocationService _revocation;
    private readonly ICurrentUser _currentUser;
    private readonly IMessagePublisher _publisher;

    public AuthService(UserManager<ApplicationUser> userManager, ITokenService tokenService,
        ITokenRevocationService revocation, ICurrentUser currentUser, IMessagePublisher publisher)
    {
        _userManager = userManager;
        _tokenService = tokenService;
        _revocation = revocation;
        _currentUser = currentUser;
        _publisher = publisher;
    }

    /// Invalidates the token this request was made with, so it stops working immediately
    /// rather than remaining usable until it expires.
    public async Task LogoutAsync()
    {
        var tokenId = _currentUser.TokenId;
        var userId = _currentUser.UserId;
        var expiresAt = _currentUser.TokenExpiresAt;
        if (tokenId is null || userId is null || expiresAt is null)
            throw new BusinessException("Niste prijavljeni.");

        await _revocation.RevokeAsync(tokenId, userId.Value, expiresAt.Value);
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest request)
    {
        var user = await _userManager.FindByNameAsync(request.Username);
        if (user is null || user.IsDeleted || !await _userManager.CheckPasswordAsync(user, request.Password))
            throw new BusinessException("Pogrešno korisničko ime ili lozinka.");

        var roles = await _userManager.GetRolesAsync(user);
        return BuildResponse(user, roles);
    }

    public async Task<AuthResponse> RegisterAsync(RegisterRequest request)
    {
        if (await _userManager.FindByNameAsync(request.Username) is not null)
            throw new BusinessException("Korisničko ime je već zauzeto.");
        if (await _userManager.FindByEmailAsync(request.Email) is not null)
            throw new BusinessException("Email adresa je već registrovana.");

        var user = new ApplicationUser
        {
            UserName = request.Username,
            Email = request.Email,
            FirstName = request.FirstName,
            LastName = request.LastName,
            PhoneNumber = request.PhoneNumber,
            CreatedAt = DateTime.UtcNow
        };

        var result = await _userManager.CreateAsync(user, request.Password);
        if (!result.Succeeded)
            throw new BusinessException(IdentityErrors.Describe(result.Errors));

        // Clients can never assign their own role: always registered as a regular user.
        await _userManager.AddToRoleAsync(user, Roles.User);

        var roles = await _userManager.GetRolesAsync(user);
        return BuildResponse(user, roles);
    }

    /// <summary>
    /// Emails a one-time code for setting a new password. The answer is the same whether or not
    /// the address belongs to an account, so the endpoint cannot be used to find out who is
    /// registered. Any code issued earlier is spent, so only the newest email works.
    /// </summary>
    public async Task RequestPasswordResetAsync(ForgotPasswordDto dto)
    {
        var email = dto.Email.Trim();
        var user = await _userManager.FindByEmailAsync(email);
        if (user is null || user.IsDeleted) return;

        // The reset token is the six-digit code itself (see PasswordResetCodeTokenProvider).
        var token = await _userManager.GeneratePasswordResetTokenAsync(user);

        var queued = await _publisher.TryPublishAsync(new EmailMessage
        {
            To = user.Email!,
            Subject = "CourtSide — kod za novu lozinku",
            Body = $"Vaš kod za postavljanje nove lozinke je: {token}\n\n" +
                   $"Kod vrijedi {PasswordResetCodeTokenProvider.Lifetime.TotalMinutes:0} minuta. " +
                   "Ako niste tražili promjenu lozinke, zanemarite ovu poruku."
        });

        // Without the email the code is useless; the user is told to try again rather than left
        // waiting for a message that will never come.
        if (!queued)
            throw new BusinessException("Slanje koda trenutno nije moguće. Pokušajte ponovo za nekoliko minuta.");
    }

    public async Task ResetPasswordAsync(ResetPasswordDto dto)
    {
        var user = await _userManager.FindByEmailAsync(dto.Email.Trim());
        // The same message covers a wrong address, a wrong code and an expired one: telling
        // them apart would say which addresses are registered.
        if (user is null || user.IsDeleted)
            throw new BusinessException("Kod nije ispravan ili je istekao.");

        // Checking the code spends it, so the password rules come first: a password that breaks
        // them must not cost the user a correct code.
        var rejected = new List<IdentityError>();
        foreach (var validator in _userManager.PasswordValidators)
        {
            var check = await validator.ValidateAsync(_userManager, user, dto.NewPassword);
            if (!check.Succeeded) rejected.AddRange(check.Errors);
        }
        if (rejected.Count > 0)
            throw new BusinessException(IdentityErrors.Describe(rejected));

        var result = await _userManager.ResetPasswordAsync(user, dto.Code.Trim(), dto.NewPassword);
        if (result.Errors.Any(e => e.Code == nameof(IdentityErrorDescriber.InvalidToken)))
            throw new BusinessException("Kod nije ispravan ili je istekao.");
        if (!result.Succeeded)
            throw new BusinessException(IdentityErrors.Describe(result.Errors));
    }

    private AuthResponse BuildResponse(ApplicationUser user, IList<string> roles)
    {
        var (token, expiration) = _tokenService.CreateToken(user, roles);
        return new AuthResponse
        {
            Token = token,
            Expiration = expiration,
            User = new UserDto
            {
                Id = user.Id,
                Username = user.UserName!,
                Email = user.Email,
                FirstName = user.FirstName,
                LastName = user.LastName,
                PhoneNumber = user.PhoneNumber,
                Role = roles.FirstOrDefault() ?? Roles.User
            }
        };
    }
}
