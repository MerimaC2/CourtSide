using CourtSide.Shared.Models;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CourtSide.Shared.Services;

/// <summary>
/// The single place that turns the venue's local wall-clock values (<see cref="DateOnly"/> +
/// <see cref="TimeOnly"/> on reservations, working hours and blocks) into points on the timeline.
/// Containers run on UTC, so comparing a local slot against <c>DateTime.UtcNow</c> directly is off
/// by the zone offset; every such comparison goes through here instead. Audit timestamps
/// (CreatedAt, PaidAt, ...) stay UTC and use <see cref="UtcNow"/>.
/// </summary>
public interface IAppClock
{
    /// <summary>Now, in UTC — for audit timestamps and token lifetimes.</summary>
    DateTime UtcNow { get; }

    TimeZoneInfo TimeZone { get; }

    /// <summary>Now, as the venue's wall clock reads it.</summary>
    DateTime LocalNow { get; }

    /// <summary>Today's calendar date at the venue.</summary>
    DateOnly Today { get; }

    /// <summary>Current time of day at the venue.</summary>
    TimeOnly LocalTimeOfDay { get; }

    /// <summary>The exact moment a local slot starts, with the zone offset applied.</summary>
    DateTimeOffset ToInstant(DateOnly date, TimeOnly time);

    /// <summary>Whether that local moment is already behind us.</summary>
    bool HasPassed(DateOnly date, TimeOnly time);

    /// <summary>How long until that local moment; negative once it has passed.</summary>
    TimeSpan TimeUntil(DateOnly date, TimeOnly time);
}

public class AppClock : IAppClock
{
    /// <summary>Windows names for the zones we are likely to be configured with, used when the
    /// IANA id is not available (running on Windows without ICU).</summary>
    private static readonly Dictionary<string, string> WindowsAliases = new(StringComparer.OrdinalIgnoreCase)
    {
        ["Europe/Sarajevo"] = "Central European Standard Time",
        ["Europe/Zagreb"] = "Central European Standard Time",
        ["Europe/Belgrade"] = "Central European Standard Time",
        ["Europe/Vienna"] = "Central European Standard Time",
    };

    private readonly TimeProvider _timeProvider;

    public AppClock(IOptions<TimeSettings> options, TimeProvider timeProvider, ILogger<AppClock> logger)
    {
        _timeProvider = timeProvider;
        TimeZone = Resolve(options.Value.TimeZoneId, logger);
        logger.LogInformation("Lokalna vremenska zona: {Zone} (trenutni pomak {Offset}).",
            TimeZone.Id, TimeZone.GetUtcOffset(_timeProvider.GetUtcNow()));
    }

    public TimeZoneInfo TimeZone { get; }

    public DateTime UtcNow => _timeProvider.GetUtcNow().UtcDateTime;

    public DateTime LocalNow => TimeZoneInfo.ConvertTimeFromUtc(UtcNow, TimeZone);

    public DateOnly Today => DateOnly.FromDateTime(LocalNow);

    public TimeOnly LocalTimeOfDay => TimeOnly.FromDateTime(LocalNow);

    public DateTimeOffset ToInstant(DateOnly date, TimeOnly time)
    {
        var local = DateTime.SpecifyKind(date.ToDateTime(time), DateTimeKind.Unspecified);

        // Twice a year a wall-clock value is either skipped or repeated. Both are resolved
        // deterministically so the same input always maps to the same instant.
        if (TimeZone.IsInvalidTime(local))
        {
            var rule = TimeZone.GetAdjustmentRules()
                .FirstOrDefault(r => local.Date >= r.DateStart && local.Date <= r.DateEnd);
            local = local.Add(rule?.DaylightDelta ?? TimeSpan.FromHours(1));
        }

        var offset = TimeZone.IsAmbiguousTime(local)
            ? TimeZone.GetAmbiguousTimeOffsets(local).Max() // the earlier of the two instants
            : TimeZone.GetUtcOffset(local);

        return new DateTimeOffset(local, offset);
    }

    public bool HasPassed(DateOnly date, TimeOnly time) => ToInstant(date, time) <= _timeProvider.GetUtcNow();

    public TimeSpan TimeUntil(DateOnly date, TimeOnly time) => ToInstant(date, time) - _timeProvider.GetUtcNow();

    private static TimeZoneInfo Resolve(string timeZoneId, ILogger logger)
    {
        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById(timeZoneId);
        }
        catch (Exception ex) when (ex is TimeZoneNotFoundException or InvalidTimeZoneException)
        {
            if (WindowsAliases.TryGetValue(timeZoneId, out var alias))
            {
                try
                {
                    var resolved = TimeZoneInfo.FindSystemTimeZoneById(alias);
                    logger.LogWarning("Zona '{Requested}' nije pronađena; koristi se '{Alias}'.", timeZoneId, alias);
                    return resolved;
                }
                catch (Exception aliasEx) when (aliasEx is TimeZoneNotFoundException or InvalidTimeZoneException)
                {
                    // fall through to the fixed-offset fallback
                }
            }

            // Degraded but running: a missing time zone database must not take the API down.
            logger.LogError(ex,
                "Vremenska zona '{Requested}' nije dostupna — koristi se fiksni pomak UTC+1 bez ljetnog računanja vremena.",
                timeZoneId);
            return TimeZoneInfo.CreateCustomTimeZone("CourtSide-Fallback", TimeSpan.FromHours(1),
                "CourtSide fallback (UTC+1)", "CourtSide fallback (UTC+1)");
        }
    }
}
