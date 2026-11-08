using CourtSide.Core.Dto;
using CourtSide.Core.Entities.Identity;
using CourtSide.Core.Exceptions;
using CourtSide.Services.Common;
using CourtSide.Shared.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace CourtSide.Services.Auth;

public interface IProfileService
{
    Task<ProfileDto> GetAsync();
    Task<ProfileDto> UpdateAsync(ProfileUpdateDto dto);
    Task ChangePasswordAsync(ChangePasswordDto dto);
    Task<(byte[] Data, string ContentType)> UploadImageAsync(IFormFile file);
    Task<(byte[] Data, string ContentType)?> GetImageAsync();
}

public class ProfileService : IProfileService
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly ICurrentUser _currentUser;

    public ProfileService(UserManager<ApplicationUser> userManager, ICurrentUser currentUser)
    {
        _userManager = userManager;
        _currentUser = currentUser;
    }

    public async Task<ProfileDto> GetAsync()
    {
        var user = await RequireUserAsync();
        return ToDto(user);
    }

    public async Task<ProfileDto> UpdateAsync(ProfileUpdateDto dto)
    {
        var user = await RequireUserAsync();
        user.FirstName = dto.FirstName;
        user.LastName = dto.LastName;
        user.PhoneNumber = dto.PhoneNumber;
        user.UpdatedAt = DateTime.UtcNow;

        var result = await _userManager.UpdateAsync(user);
        if (!result.Succeeded)
            throw new BusinessException(IdentityErrors.Describe(result.Errors));

        return ToDto(user);
    }

    public async Task ChangePasswordAsync(ChangePasswordDto dto)
    {
        var user = await RequireUserAsync();
        var result = await _userManager.ChangePasswordAsync(user, dto.CurrentPassword, dto.NewPassword);
        if (!result.Succeeded)
            throw new BusinessException(IdentityErrors.Describe(result.Errors));
    }

    public async Task<(byte[] Data, string ContentType)> UploadImageAsync(IFormFile file)
    {
        var (data, contentType) = await ImageValidation.ReadAndValidateAsync(file);

        var user = await RequireUserAsync();
        user.ProfileImage = data;
        user.ProfileImageContentType = contentType;
        user.UpdatedAt = DateTime.UtcNow;
        await _userManager.UpdateAsync(user);

        return (data, contentType);
    }

    public async Task<(byte[] Data, string ContentType)?> GetImageAsync()
    {
        var user = await RequireUserAsync();
        if (user.ProfileImage is null || user.ProfileImageContentType is null) return null;
        return (user.ProfileImage, user.ProfileImageContentType);
    }

    private async Task<ApplicationUser> RequireUserAsync()
    {
        var userId = _currentUser.UserId ?? throw new BusinessException("Niste prijavljeni.");
        return await _userManager.Users.FirstOrDefaultAsync(u => u.Id == userId)
            ?? throw new NotFoundException("Korisnik", userId);
    }

    private static ProfileDto ToDto(ApplicationUser user) => new()
    {
        Id = user.Id,
        Username = user.UserName!,
        Email = user.Email,
        FirstName = user.FirstName,
        LastName = user.LastName,
        PhoneNumber = user.PhoneNumber,
        HasProfileImage = user.ProfileImage is not null
    };
}
