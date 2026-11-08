namespace CourtSide.Core.Dto;

public class ForgotPasswordDto
{
    public string Email { get; set; } = null!;
}

public class ResetPasswordDto
{
    public string Email { get; set; } = null!;

    /// <summary>The code from the email.</summary>
    public string Code { get; set; } = null!;

    public string NewPassword { get; set; } = null!;
}
