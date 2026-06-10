namespace CourtSide.Shared.Messages;

/// <summary>Email job published to RabbitMQ; consumed and sent by the Worker service.</summary>
public class EmailMessage
{
    public string To { get; set; } = null!;
    public string Subject { get; set; } = null!;
    public string Body { get; set; } = null!;
}
