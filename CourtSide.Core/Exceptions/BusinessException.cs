namespace CourtSide.Core.Exceptions;

/// <summary>
/// Thrown when a business rule is violated. Mapped to HTTP 400 by the exception middleware.
/// </summary>
public class BusinessException : Exception
{
    public BusinessException(string message) : base(message) { }
}
