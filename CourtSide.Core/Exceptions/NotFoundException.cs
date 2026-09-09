namespace CourtSide.Core.Exceptions;

/// <summary>
/// Thrown when a requested entity does not exist. Mapped to HTTP 404 by the exception middleware.
/// </summary>
public class NotFoundException : Exception
{
    public NotFoundException(string message) : base(message) { }

    /// <summary>The wording avoids agreeing with the entity's gender, so one template fits
    /// "rezervacija", "teren" and "država" alike.</summary>
    public NotFoundException(string entity, object key)
        : base($"Ne postoji {entity.ToLowerInvariant()} sa identifikatorom '{key}'.") { }
}
