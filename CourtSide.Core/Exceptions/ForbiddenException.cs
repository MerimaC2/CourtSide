namespace CourtSide.Core.Exceptions;

/// <summary>
/// Thrown when the caller is authenticated but the record is not theirs to touch. Mapped to
/// HTTP 403 by the exception middleware — a refusal to act on someone else's data is not the
/// same as a malformed request, and clients need to tell the two apart.
/// </summary>
public class ForbiddenException : Exception
{
    public ForbiddenException(string message) : base(message) { }
}
