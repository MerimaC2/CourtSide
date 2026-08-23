using CourtSide.Core.Dto;
using CourtSide.Core.Entities.Identity;
using CourtSide.Core.Exceptions;
using CourtSide.Shared.Constants;
using CourtSide.Shared.Services;
using Microsoft.AspNetCore.Identity;

namespace CourtSide.Services.Auth;

public interface IAuthService
{
    Task<AuthResponse> LoginAsync(LoginRequest request);
    Task<AuthResponse> RegisterAsync(RegisterRequest request);
    Task LogoutAsync();
}

public class AuthService : IAuthService
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly ITokenService _tokenService;
    private readonly ITokenRevocationService _revocation;
    private readonly ICurrentUser _currentUser;

    public AuthService(UserManager<ApplicationUser> userManager, ITokenService tokenService,
        ITokenRevocationService revocation, ICurrentUser currentUser)
    {
        _userManager = userManager;
        _tokenService = tokenService;
        _revocation = revocation;
        _currentUser = currentUser;
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
            throw new BusinessException(string.Join(" ", result.Errors.Select(e => e.Description)));

        // Clients can never assign their own role: always registered as a regular user.
        await _userManager.AddToRoleAsync(user, Roles.User);

        var roles = await _userManager.GetRolesAsync(user);
        return BuildResponse(user, roles);
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
