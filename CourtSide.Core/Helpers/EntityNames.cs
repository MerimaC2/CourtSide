namespace CourtSide.Core.Helpers;

/// <summary>
/// Bosnian names for the entity types, used by the generic CRUD service when a record is missing.
/// Without it the class name leaks into a user-facing message ("Ne postoji sportcenter ...").
/// </summary>
public static class EntityNames
{
    private static readonly Dictionary<string, string> Names = new(StringComparer.Ordinal)
    {
        ["City"] = "grad",
        ["Country"] = "država",
        ["Court"] = "teren",
        ["CourtAvailabilityBlock"] = "blokada",
        ["CourtReview"] = "recenzija",
        ["News"] = "obavijest",
        ["Notification"] = "notifikacija",
        ["Payment"] = "plaćanje",
        ["Reservation"] = "rezervacija",
        ["Sport"] = "sport",
        ["SportCenter"] = "sportski centar"
    };

    /// <summary>Falls back to the type name so a newly added entity still produces a message.</summary>
    public static string For(Type type) =>
        Names.TryGetValue(type.Name, out var name) ? name : type.Name;
}
