using CourtSide.Core.Dto;
using CourtSide.Core.Entities.Identity;
using CourtSide.Core.Exceptions;
using CourtSide.Shared.Constants;
using Microsoft.AspNetCore.Identity;

namespace CourtSide.Services.Auth;

public interface IAuthService
{
    Task<AuthResponse> LoginAsync(LoginRequest request);
    Task<AuthResponse> RegisterAsync(RegisterRequest request);
}

public class AuthService : IAuthService
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly ITokenService _tokenService;

    public AuthService(UserManager<ApplicationUser> userManager, ITokenService tokenService)
    {
        _userManager = userManager;
        _tokenService = tokenService;
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
