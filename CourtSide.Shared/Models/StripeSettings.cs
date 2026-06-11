namespace CourtSide.Shared.Models;

/// <summary>Stripe (sandbox) configuration. Empty keys mean online payments are disabled (cash still works).</summary>
public class StripeSettings
{
    public string SecretKey { get; set; } = "";
    public string PublishableKey { get; set; } = "";
    public string WebhookSecret { get; set; } = "";

    public bool IsConfigured => !string.IsNullOrWhiteSpace(SecretKey);
}
