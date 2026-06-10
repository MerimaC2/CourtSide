using CourtSide.Shared.Models;
using CourtSide.Worker.Services;
using CourtSide.Worker.Workers;
using DotNetEnv;
using Microsoft.Extensions.Options;

// Load .env for local development. In Docker, configuration comes from env_file.
Env.TraversePath().Load();

static string Opt(string key, string fallback) =>
    Environment.GetEnvironmentVariable(key) is { Length: > 0 } value ? value : fallback;

var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddSingleton(Options.Create(new RabbitMqSettings
{
    Host = Opt("RABBITMQ_HOST", "localhost"),
    Port = int.TryParse(Opt("RABBITMQ_PORT", "5672"), out var rabbitPort) ? rabbitPort : 5672,
    Username = Opt("RABBITMQ_USER", "guest"),
    Password = Opt("RABBITMQ_PASSWORD", "guest"),
    Queue = Opt("RABBITMQ_QUEUE", "courtside.notifications")
}));

builder.Services.AddSingleton(Options.Create(new SmtpSettings
{
    Host = Opt("SMTP_HOST", "localhost"),
    Port = int.TryParse(Opt("SMTP_PORT", "587"), out var smtpPort) ? smtpPort : 587,
    Username = Opt("SMTP_USERNAME", ""),
    Password = Opt("SMTP_PASSWORD", ""),
    UseSsl = !bool.TryParse(Opt("SMTP_USE_SSL", "true"), out var useSsl) || useSsl,
    From = Opt("SMTP_FROM", "no-reply@courtside.local")
}));

builder.Services.AddSingleton<EmailService>();
builder.Services.AddHostedService<EmailConsumerWorker>();

var host = builder.Build();
host.Run();
