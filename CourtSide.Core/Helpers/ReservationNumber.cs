namespace CourtSide.Core.Helpers;

/// <summary>
/// The reservation number format (<c>RZ-{timestamp}-{suffix}</c>) and its short display form.
/// Both live here so the generated value and everything that shows it stay in step.
/// </summary>
public static class ReservationNumber
{
    public static string Generate() =>
        $"RZ-{DateTime.UtcNow:yyyyMMddHHmmss}-{Guid.NewGuid().ToString("N")[..4].ToUpperInvariant()}";

    /// <summary>
    /// The distinctive suffix on its own (<c>RZ-20260811121848-FFD2</c> becomes <c>FFD2</c>) for
    /// places where the whole number is too long to read, such as reports and notifications.
    /// Anything not matching the expected shape is returned unchanged.
    /// </summary>
    public static string Short(string reservationNumber)
    {
        var parts = reservationNumber.Split('-');
        return parts.Length == 3 ? parts[^1] : reservationNumber;
    }
}
