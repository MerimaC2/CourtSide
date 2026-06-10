namespace CourtSide.Shared.Models;

public class SmtpSettings
{
    public string Host { get; set; } = "localhost";
    public int Port { get; set; } = 587;
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public bool UseSsl { get; set; } = true;
    public string From { get; set; } = "no-reply@courtside.local";
}
