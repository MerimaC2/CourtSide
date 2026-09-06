using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace CourtSide.Api.Json;

/// <summary>
/// Writes <see cref="DateTime"/> values with an explicit UTC marker. Audit timestamps are stored
/// in UTC, but SQL Server returns them with <see cref="DateTimeKind.Unspecified"/>, so they would
/// serialize without a zone and every client would read them as its own local time. Slot values
/// (<see cref="DateOnly"/>/<see cref="TimeOnly"/>) and <see cref="DateTimeOffset"/> are unaffected.
/// </summary>
public class UtcDateTimeConverter : JsonConverter<DateTime>
{
    private const string Format = "yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'";

    public override DateTime Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        => reader.GetDateTime();

    public override void Write(Utf8JsonWriter writer, DateTime value, JsonSerializerOptions options)
    {
        var utc = value.Kind switch
        {
            DateTimeKind.Utc => value,
            DateTimeKind.Local => value.ToUniversalTime(),
            _ => DateTime.SpecifyKind(value, DateTimeKind.Utc)
        };
        writer.WriteStringValue(utc.ToString(Format, CultureInfo.InvariantCulture));
    }
}
