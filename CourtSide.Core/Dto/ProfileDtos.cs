namespace CourtSide.Core.Dto;

public class ProfileDto
{
    public int Id { get; set; }
    public string Username { get; set; } = null!;
    public string? Email { get; set; }
    public string FirstName { get; set; } = null!;
    public string LastName { get; set; } = null!;
    public string? PhoneNumber { get; set; }
    public bool HasProfileImage { get; set; }
}

public class ProfileUpdateDto
{
    public string FirstName { get; set; } = null!;
    public string LastName { get; set; } = null!;
    public string? PhoneNumber { get; set; }
}

public class ChangePasswordDto
{
    public string CurrentPassword { get; set; } = null!;
    public string NewPassword { get; set; } = null!;
}
