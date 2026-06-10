using System.Net;
using System.Net.Mail;
using CourtSide.Shared.Messages;
using CourtSide.Shared.Models;
using Microsoft.Extensions.Options;

namespace CourtSide.Worker.Services;

/// <summary>Sends emails over SMTP (real work performed by the worker service).</summary>
public class EmailService
{
    private readonly SmtpSettings _settings;
    private readonly ILogger<EmailService> _logger;

    public EmailService(IOptions<SmtpSettings> settings, ILogger<EmailService> logger)
    {
        _settings = settings.Value;
        _logger = logger;
    }

    public async Task SendAsync(EmailMessage message)
    {
        using var client = new SmtpClient(_settings.Host, _settings.Port)
        {
            EnableSsl = _settings.UseSsl,
            Credentials = new NetworkCredential(_settings.Username, _settings.Password)
        };

        using var mail = new MailMessage(_settings.From, message.To, message.Subject, message.Body);
        await client.SendMailAsync(mail);

        _logger.LogInformation("Email poslan na {To}: {Subject}", message.To, message.Subject);
    }
}
