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
                var json = Encoding.UTF8.GetString(ea.Body.ToArray());
                var message = JsonSerializer.Deserialize<EmailMessage>(json);
                if (message is not null)
                    await _email.SendAsync(message);

                _channel!.BasicAck(ea.DeliveryTag, multiple: false);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Greška pri obradi email poruke.");
                _channel!.BasicNack(ea.DeliveryTag, multiple: false, requeue: false);
            }
        };

        _channel.BasicConsume(_rabbit.Queue, autoAck: false, consumer);
        _logger.LogInformation("Worker sluša RabbitMQ red '{Queue}'.", _rabbit.Queue);
    }

    public override void Dispose()
    {
        _channel?.Dispose();
        _connection?.Dispose();
        base.Dispose();
    }
}
