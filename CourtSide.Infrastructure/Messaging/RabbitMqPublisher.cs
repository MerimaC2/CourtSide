using System.Text;
using System.Text.Json;
using CourtSide.Shared.Messaging;
using CourtSide.Shared.Models;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;

namespace CourtSide.Infrastructure.Messaging;

/// <summary>
/// Publishes messages to a durable RabbitMQ queue. Failures are logged and swallowed so that
/// core operations (e.g. creating a reservation) are not broken when the broker is unavailable.
/// </summary>
public class RabbitMqPublisher : IMessagePublisher, IDisposable
{
    private readonly RabbitMqSettings _settings;
    private readonly ILogger<RabbitMqPublisher> _logger;
    private readonly object _lock = new();

    private IConnection? _connection;
    private IModel? _channel;

    public RabbitMqPublisher(IOptions<RabbitMqSettings> settings, ILogger<RabbitMqPublisher> logger)
    {
        _settings = settings.Value;
        _logger = logger;
    }

    public Task PublishAsync<T>(T message)
    {
        try
        {
            lock (_lock)
            {
                EnsureChannel();

                var json = JsonSerializer.Serialize(message);
                var body = Encoding.UTF8.GetBytes(json);

                var properties = _channel!.CreateBasicProperties();
                properties.Persistent = true;
                properties.Type = typeof(T).Name;

                _channel.BasicPublish(exchange: string.Empty, routingKey: _settings.Queue,
                    basicProperties: properties, body: body);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Slanje poruke na RabbitMQ nije uspjelo (queue {Queue}).", _settings.Queue);
        }

        return Task.CompletedTask;
    }

    private void EnsureChannel()
    {
        if (_channel is { IsOpen: true }) return;

        var factory = new ConnectionFactory
        {
            HostName = _settings.Host,
            Port = _settings.Port,
            UserName = _settings.Username,
            Password = _settings.Password
        };

        _connection = factory.CreateConnection();
        _channel = _connection.CreateModel();
        _channel.QueueDeclare(_settings.Queue, durable: true, exclusive: false, autoDelete: false, arguments: null);
    }

    public void Dispose()
    {
        _channel?.Dispose();
        _connection?.Dispose();
    }
}
