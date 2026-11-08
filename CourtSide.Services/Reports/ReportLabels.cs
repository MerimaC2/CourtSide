using CourtSide.Core.Enumerations;

namespace CourtSide.Services.Reports;

/// <summary>
/// Wording for the generated PDF. The report is produced on the server, so the client
/// tells it which language the user is currently reading the app in and the matching
/// set is used; anything unrecognised falls back to Bosnian.
/// </summary>
public sealed class ReportLabels
{
    public required string Subtitle { get; init; }
    public required string Period { get; init; }
    public required string GeneratedAt { get; init; }

    public required string Summary { get; init; }
    public required string TotalReservations { get; init; }
    public required string CollectedRevenue { get; init; }
    public required string PaidReservations { get; init; }

    public required string ByCourt { get; init; }
    public required string Court { get; init; }
    public required string Centre { get; init; }
    public required string ReservationCount { get; init; }
    public required string Collected { get; init; }
    public required string NoDataForPeriod { get; init; }

    public required string Reservations { get; init; }
    public required string Number { get; init; }
    public required string Date { get; init; }
    public required string Slot { get; init; }
    public required string Client { get; init; }
    public required string Status { get; init; }
    public required string Paid { get; init; }
    public required string Yes { get; init; }
    public required string No { get; init; }
    public required string NoReservationsForPeriod { get; init; }

    public required string OccupancySubtitle { get; init; }
    public required string TopSlots { get; init; }
    public required string TimeSlot { get; init; }
    public required string BookingCount { get; init; }
    public required string OccupancyByCourt { get; init; }
    public required string ReservedHours { get; init; }
    public required string AvailableHours { get; init; }
    public required string OccupancyPercent { get; init; }

    public required string Page { get; init; }
    public required IReadOnlyDictionary<ReservationStatus, string> Statuses { get; init; }

    public static ReportLabels For(string? language) =>
        string.Equals(language, "en", StringComparison.OrdinalIgnoreCase) ? English : Bosnian;

    private static readonly ReportLabels Bosnian = new()
    {
        Subtitle = "Izvještaj o rezervacijama i prihodu",
        Period = "Period",
        GeneratedAt = "Generisano",
        Summary = "Sažetak",
        TotalReservations = "Ukupno rezervacija",
        CollectedRevenue = "Naplaćeni prihod",
        PaidReservations = "Plaćenih rezervacija",
        ByCourt = "Po terenu",
        Court = "Teren",
        Centre = "Centar",
        ReservationCount = "Rezervacija",
        Collected = "Naplaćeno (BAM)",
        NoDataForPeriod = "Nema podataka za period.",
        Reservations = "Rezervacije",
        Number = "Broj",
        Date = "Datum",
        Slot = "Termin",
        Client = "Klijent",
        Status = "Status",
        Paid = "Plaćeno",
        Yes = "Da",
        No = "Ne",
        NoReservationsForPeriod = "Nema rezervacija za period.",
        OccupancySubtitle = "Izvještaj o popunjenosti terena",
        TopSlots = "Najtraženiji termini",
        TimeSlot = "Termin",
        BookingCount = "Broj rezervacija",
        OccupancyByCourt = "Popunjenost po terenu",
        ReservedHours = "Rezervisani sati",
        AvailableHours = "Dostupni sati",
        OccupancyPercent = "Popunjenost",
        Page = "Strana ",
        Statuses = new Dictionary<ReservationStatus, string>
        {
            [ReservationStatus.Pending] = "Na čekanju",
            [ReservationStatus.Confirmed] = "Potvrđeno",
            [ReservationStatus.Cancelled] = "Otkazano",
            [ReservationStatus.Completed] = "Završeno"
        }
    };

    private static readonly ReportLabels English = new()
    {
        Subtitle = "Reservations and revenue report",
        Period = "Period",
        GeneratedAt = "Generated",
        Summary = "Summary",
        TotalReservations = "Total reservations",
        CollectedRevenue = "Collected revenue",
        PaidReservations = "Paid reservations",
        ByCourt = "By court",
        Court = "Court",
        Centre = "Centre",
        ReservationCount = "Reservations",
        Collected = "Collected (BAM)",
        NoDataForPeriod = "No data for this period.",
        Reservations = "Reservations",
        Number = "Number",
        Date = "Date",
        Slot = "Time slot",
        Client = "Client",
        Status = "Status",
        Paid = "Paid",
        Yes = "Yes",
        No = "No",
        NoReservationsForPeriod = "No reservations for this period.",
        OccupancySubtitle = "Court occupancy report",
        TopSlots = "Most requested time slots",
        TimeSlot = "Time slot",
        BookingCount = "Bookings",
        OccupancyByCourt = "Occupancy by court",
        ReservedHours = "Reserved hours",
        AvailableHours = "Available hours",
        OccupancyPercent = "Occupancy",
        Page = "Page ",
        Statuses = new Dictionary<ReservationStatus, string>
        {
            [ReservationStatus.Pending] = "Pending",
            [ReservationStatus.Confirmed] = "Confirmed",
            [ReservationStatus.Cancelled] = "Cancelled",
            [ReservationStatus.Completed] = "Completed"
        }
    };
}
