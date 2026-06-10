namespace CourtSide.Core.Entities.Base;

/// <summary>
/// Base for all domain entities: integer PK, audit timestamps and soft-delete flag.
/// </summary>
public abstract class BaseEntity
{
    public int Id { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public bool IsDeleted { get; set; }
}
