using System.Text;
using System.Text.Json;
using CourtSide.Shared.Messages;
using CourtSide.Shared.Models;
using CourtSide.Worker.Services;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace CourtSide.Worker.Workers;

/// <summary>Consumes email jobs from RabbitMQ and sends them via SMTP.</summary>
public class EmailConsumerWorker : BackgroundService
{
    private readonly RabbitMqSettings _rabbit;
    private readonly EmailService _email;
    private readonly ILogger<EmailConsumerWorker> _logger;

    private IConnection? _connection;
    private IModel? _channel;

    public EmailConsumerWorker(IOptions<RabbitMqSettings> rabbit, EmailService email,
        ILogger<EmailConsumerWorker> logger)
    {
        _rabbit = rabbit.Value;
        _email = email;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Retry until the broker is reachable (e.g. while RabbitMQ container is still starting).
        while (!stoppingToken.IsCancellationRequested && _channel is null)
        {
            try
            {
                StartConsuming();
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "RabbitMQ nije dostupan. Ponovni pokušaj za 5s...");
                await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
            }
        }
    }

    private void StartConsuming()
    {
        var factory = new ConnectionFactory
        {
            HostName = _rabbit.Host,
            Port = _rabbit.Port,
            UserName = _rabbit.Username,
            Password = _rabbit.Password,
            DispatchConsumersAsync = true
        };

        _connection = factory.CreateConnection();
        _channel = _connection.CreateModel();
        _channel.QueueDeclare(_rabbit.Queue, durable: true, exclusive: false, autoDelete: false, arguments: null);

        var consumer = new AsyncEventingBasicConsumer(_channel);
        consumer.Received += async (_, ea) =>
        {
            try
            {
                EmailMessage? message;
                try
                {
                    var json = Encoding.UTF8.GetString(ea.Body.ToArray());
                    message = JsonSerializer.Deserialize<EmailMessage>(json);
                }
                catch (JsonException ex)
                {
                    // A malformed payload will never succeed on a retry, so it is rejected without
                    // requeueing. Left unacknowledged it would stay unacknowledged and stall the queue.
                    _logger.LogError(ex, "Neispravna poruka u redu '{Queue}': {Payload}", _rabbit.Queue, Excerpt(ea));
                    _channel!.BasicNack(ea.DeliveryTag, multiple: false, requeue: false);
                    return;
                }

                if (message is null || string.IsNullOrWhiteSpace(message.To))
                {
                    _logger.LogError("Poruka bez primaoca u redu '{Queue}': {Payload}", _rabbit.Queue, Excerpt(ea));
                    _channel!.BasicNack(ea.DeliveryTag, multiple: false, requeue: false);
                    return;
                }

                if (!await TrySendWithRetryAsync(message))
                {
                    _channel!.BasicNack(ea.DeliveryTag, multiple: false, requeue: false);
                    return;
                }

                _channel!.BasicAck(ea.DeliveryTag, multiple: false);
            }
            catch (Exception ex)
            {
                // The consumer callback is the outermost frame here — an escaping exception would
                // leave the delivery in limbo, so it is logged rather than thrown. The delivery is
                // handed back to the queue for one more attempt only: a delivery that fails again
                // after being redelivered is dropped, so a message that can never be processed is
                // not cycled through the queue forever. If even the nack fails the channel is gone
                // and the broker redelivers on reconnect.
                _logger.LogError(ex, "Neočekivana greška pri obradi poruke iz reda '{Queue}'.", _rabbit.Queue);
                var requeue = !ea.Redelivered;
                if (!requeue)
                    _logger.LogError("Poruka iz reda '{Queue}' nije obrađena ni nakon ponovne isporuke i odbacuje se: {Payload}",
                        _rabbit.Queue, Excerpt(ea));
                try { _channel?.BasicNack(ea.DeliveryTag, multiple: false, requeue: requeue); }
                catch (Exception nackEx)
                {
                    _logger.LogError(nackEx, "Poruku nije bilo moguće vratiti u red '{Queue}'.", _rabbit.Queue);
                }
            }
        };

        _channel.BasicConsume(_rabbit.Queue, autoAck: false, consumer);
        _logger.LogInformation("Worker sluša RabbitMQ red '{Queue}'.", _rabbit.Queue);
    }

    /// <summary>Start of a payload we could not process, so the log shows what arrived.</summary>
    private static string Excerpt(BasicDeliverEventArgs args)
    {
        var text = Encoding.UTF8.GetString(args.Body.ToArray());
        return text.Length <= 200 ? text : text[..200] + "...";
    }

    /// <summary>Retries a failed send with exponential backoff (1s, 2s, 4s, 8s) before giving up.</summary>
    private async Task<bool> TrySendWithRetryAsync(EmailMessage message)
    {
        var delay = TimeSpan.FromSeconds(1);
        for (var attempt = 1; attempt <= 5; attempt++)
        {
            try
            {
                await _email.SendAsync(message);
                return true;
            }
            catch (Exception ex)
            {
                if (attempt == 5)
                {
                    _logger.LogError(ex, "Slanje email poruke nije uspjelo ni nakon {Attempts} pokušaja.", attempt);
                    return false;
                }

                _logger.LogWarning(ex, "Slanje email poruke nije uspjelo (pokušaj {Attempt}). Ponovni pokušaj za {Delay}s.",
                    attempt, delay.TotalSeconds);
                await Task.Delay(delay);
                delay *= 2;
            }
        }

        return false;
    }

    public override void Dispose()
    {
        _channel?.Dispose();
        _connection?.Dispose();
        base.Dispose();
    }
}
