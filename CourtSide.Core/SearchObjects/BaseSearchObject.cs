namespace CourtSide.Core.SearchObjects;

/// <summary>Base paging/search parameters. PageSize is clamped to <see cref="MaxPageSize"/> server-side.</summary>
public class BaseSearchObject
{
    public const int MaxPageSize = 100;

    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;

    /// <summary>Free-text filter (matched against the entity's main text field).</summary>
    public string? SearchTerm { get; set; }
}
