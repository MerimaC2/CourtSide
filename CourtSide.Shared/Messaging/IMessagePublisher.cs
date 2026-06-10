namespace CourtSide.Shared.Messaging;

/// <summary>Publishes messages to the message broker (RabbitMQ). Implemented in the Infrastructure layer.</summary>
public interface IMessagePublisher
{
    Task PublishAsync<T>(T message);
}
