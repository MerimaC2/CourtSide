namespace CourtSide.Shared.Models;

public class JwtSettings
{
    public string Key { get; set; } = null!;
    public string Issuer { get; set; } = "CourtSide";
    public string Audience { get; set; } = "CourtSideClients";
    public int ExpiryMinutes { get; set; } = 120;
}
