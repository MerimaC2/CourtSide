namespace CourtSide.Core.Helpers;

/// <summary>
/// The one definition of which slots a court offers. Availability, booking and blocking all
/// derive from it, so the server can never accept a slot it does not itself offer, and the
/// occupancy report can rely on every reservation matching a slot.
/// </summary>
public static class SlotGrid
{
    /// <summary>Slots are one hour long, aligned to the court's opening time.</summary>
    public static readonly TimeSpan SlotDuration = TimeSpan.FromHours(1);

    /// <summary>The slots offered between the given opening hours.</summary>
    public static IEnumerable<(TimeOnly Start, TimeOnly End)> Build(TimeOnly openTime, TimeOnly closeTime)
    {
        for (var start = openTime; start < closeTime; start = start.Add(SlotDuration))
        {
            var end = start.Add(SlotDuration);
            // A wrapped end means the slot would run past midnight; the last partial hour is dropped.
            if (end <= start || end > closeTime) yield break;
            yield return (start, end);
        }
    }

    /// <summary>Whether the range is exactly one offered slot — the rule for a reservation.</summary>
    public static bool IsSlot(TimeOnly openTime, TimeOnly closeTime, TimeOnly start, TimeOnly end)
        => Build(openTime, closeTime).Any(slot => slot.Start == start && slot.End == end);

    /// <summary>
    /// Whether the range covers one or more whole consecutive slots — the rule for a block,
    /// since maintenance may take several hours.
    /// </summary>
    public static bool IsSlotRange(TimeOnly openTime, TimeOnly closeTime, TimeOnly start, TimeOnly end)
    {
        if (end <= start) return false;
        var slots = Build(openTime, closeTime).ToList();
        return slots.Any(slot => slot.Start == start) && slots.Any(slot => slot.End == end);
    }

    /// <summary>Whether two half-open time ranges overlap.</summary>
    public static bool Overlaps(TimeOnly startA, TimeOnly endA, TimeOnly startB, TimeOnly endB)
        => startA < endB && startB < endA;
}
