namespace CourtSide.Shared.Messaging;

/// <summary>Publishes messages to the message broker (RabbitMQ). Implemented in the Infrastructure layer.</summary>
public interface IMessagePublisher
{
    /// <summary>
    /// Sends the message, swallowing a broker failure: a notification that could not be queued
    /// must not undo the operation it accompanies (a booking, a cancellation).
    /// </summary>
    Task PublishAsync<T>(T message);

    /// <summary>
    /// Sends the message and reports whether it reached the broker, for callers whose whole
    /// purpose is the message — an emailed code that was never queued must not be answered
    /// with "sent".
    /// </summary>
    Task<bool> TryPublishAsync<T>(T message);
}
